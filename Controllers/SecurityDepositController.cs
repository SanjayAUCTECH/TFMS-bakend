using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SecurityDepositController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public SecurityDepositController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>GET api/securitydeposit/status/{contractId}</summary>
    [HttpGet("status/{contractId}")]
    public async Task<IActionResult> GetStatus(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT c.ContractId, t.Name AS TenantName,
                   ISNULL(c.SecurityDeposit, 0) AS DepositAmount,
                   ISNULL(c.SecurityDepositPaid, 0) AS DepositPaid,
                   ISNULL(c.SecurityDeposit, 0) - ISNULL(c.SecurityDepositPaid, 0) AS DepositBalance,
                   ISNULL(c.SecurityDepositStatus, 'Pending') AS Status
            FROM Contracts c
            JOIN Tenants t ON t.Id = c.TenantId
            WHERE c.ContractId = @ContractId", conn);
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync())
            return NotFound(ApiResponse<object>.Fail("Contract not found."));

        return Ok(ApiResponse<SecurityDepositStatusResponse>.Ok(new SecurityDepositStatusResponse
        {
            ContractId     = r.GetString(r.GetOrdinal("ContractId")),
            TenantName     = r.IsDBNull(r.GetOrdinal("TenantName")) ? "" : r.GetString(r.GetOrdinal("TenantName")),
            DepositAmount  = r.GetDecimal(r.GetOrdinal("DepositAmount")),
            DepositPaid    = r.GetDecimal(r.GetOrdinal("DepositPaid")),
            DepositBalance = r.GetDecimal(r.GetOrdinal("DepositBalance")),
            Status         = r.GetString(r.GetOrdinal("Status")),
        }, "Security deposit status retrieved."));
    }

    /// <summary>POST api/securitydeposit/receive — Receive security deposit from tenant</summary>
    [HttpPost("receive")]
    public async Task<IActionResult> Receive([FromBody] ReceiveSecurityDepositRequest req)
    {
        if (string.IsNullOrEmpty(req.ContractId))
            return BadRequest(ApiResponse<object>.Fail("ContractId required."));
        if (req.Amount <= 0)
            return BadRequest(ApiResponse<object>.Fail("Amount must be > 0."));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Validate contract and check deposit
        decimal depositAmount = 0, depositPaid = 0;
        int tenantId = 0;
        await using (var chk = new SqlCommand(@"
            SELECT ISNULL(SecurityDeposit, 0), ISNULL(SecurityDepositPaid, 0), TenantId
            FROM Contracts WHERE ContractId = @ContractId", conn))
        {
            chk.Parameters.AddWithValue("@ContractId", req.ContractId);
            await using var r = await chk.ExecuteReaderAsync();
            if (!await r.ReadAsync())
                return NotFound(ApiResponse<object>.Fail("Contract not found."));
            depositAmount = r.GetDecimal(0);
            depositPaid = r.GetDecimal(1);
            tenantId = r.GetInt32(2);
        }

        if (depositAmount <= 0)
            return BadRequest(ApiResponse<object>.Fail("No security deposit set for this contract."));

        var remaining = depositAmount - depositPaid;
        if (req.Amount > remaining)
            return BadRequest(ApiResponse<object>.Fail($"Amount exceeds pending deposit. Remaining: {remaining}"));

        var newPaid = depositPaid + req.Amount;
        var newStatus = newPaid >= depositAmount ? "Received" : "Partially Received";

        // Update contract
        await using (var upd = new SqlCommand(@"
            UPDATE Contracts SET SecurityDepositPaid = @Paid, SecurityDepositStatus = @Status, UpdatedAt = GETDATE()
            WHERE ContractId = @ContractId", conn))
        {
            upd.Parameters.AddWithValue("@ContractId", req.ContractId);
            upd.Parameters.AddWithValue("@Paid", newPaid);
            upd.Parameters.AddWithValue("@Status", newStatus);
            await upd.ExecuteNonQueryAsync();
        }

        // Update Fund Pool
        if (req.FundPoolId.HasValue && req.Amount > 0)
        {
            await using var fp = new SqlCommand("UPDATE FundPools SET Balance = Balance + @Amt, UpdatedAt = GETDATE() WHERE Id = @Id", conn);
            fp.Parameters.AddWithValue("@Amt", req.Amount);
            fp.Parameters.AddWithValue("@Id", req.FundPoolId.Value);
            await fp.ExecuteNonQueryAsync();
        }

        // Create TxnRecord (SD-CR)
        var txnId = $"TXN-{req.PaidDate:yyyyMMdd}-{DateTime.Now.Ticks % 1000000:D6}";
        await using (var ins = new SqlCommand(@"
            INSERT INTO TxnRecords (TxnId, TxnType, ContractId, ContractCode, TenantId, CampId, TotalAmount, Amount,
                PaidDate, PaymentMode, PaymentModeId, ChequeNumber, Description, ReceivedBy, FundPoolId, FundPoolName, IssuedBy, CreatedAt, UpdatedAt)
            VALUES (@TxnId, 'SD-CR', @ContractId, @ContractId, @TenantId,
                ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId=@ContractId), 0),
                @Amount, @Amount, @PaidDate, @PaymentMode, @PaymentModeId, @ChequeNumber,
                @Description, @ReceivedBy, @FundPoolId, @FundPoolName, @ReceivedBy, GETDATE(), GETDATE())", conn))
        {
            ins.Parameters.AddWithValue("@TxnId", txnId);
            ins.Parameters.AddWithValue("@ContractId", req.ContractId);
            ins.Parameters.AddWithValue("@TenantId", tenantId);
            ins.Parameters.AddWithValue("@Amount", req.Amount);
            ins.Parameters.AddWithValue("@PaidDate", req.PaidDate);
            ins.Parameters.AddWithValue("@PaymentMode", req.PaymentMode);
            ins.Parameters.AddWithValue("@PaymentModeId", (object?)req.PaymentModeId ?? DBNull.Value);
            ins.Parameters.AddWithValue("@ChequeNumber", req.ChequeNumber);
            ins.Parameters.AddWithValue("@Description", $"Security Deposit Received - {req.Notes}");
            ins.Parameters.AddWithValue("@ReceivedBy", req.ReceivedBy);
            ins.Parameters.AddWithValue("@FundPoolId", (object?)req.FundPoolId ?? DBNull.Value);
            ins.Parameters.AddWithValue("@FundPoolName", req.FundPoolName);
            await ins.ExecuteNonQueryAsync();
        }

        return Ok(ApiResponse<object>.Ok(new
        {
            contractId = req.ContractId,
            amountReceived = req.Amount,
            totalPaid = newPaid,
            depositAmount,
            status = newStatus,
        }, $"Security deposit of {req.Amount} received successfully. Status: {newStatus}"));
    }

    /// <summary>POST api/securitydeposit/settle — Settle deposit at contract end (adjust/refund/forfeit)</summary>
    [HttpPost("settle")]
    public async Task<IActionResult> Settle([FromBody] SettleSecurityDepositRequest req)
    {
        if (string.IsNullOrEmpty(req.ContractId))
            return BadRequest(ApiResponse<object>.Fail("ContractId required."));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        decimal depositPaid = 0;
        int tenantId = 0;
        await using (var chk = new SqlCommand("SELECT ISNULL(SecurityDepositPaid, 0), TenantId FROM Contracts WHERE ContractId=@CId", conn))
        {
            chk.Parameters.AddWithValue("@CId", req.ContractId);
            await using var r = await chk.ExecuteReaderAsync();
            if (!await r.ReadAsync()) return NotFound(ApiResponse<object>.Fail("Contract not found."));
            depositPaid = r.GetDecimal(0);
            tenantId = r.GetInt32(1);
        }

        var totalSettled = req.AdjustAmount + req.RefundAmount + req.ForfeitAmount;
        if (totalSettled > depositPaid)
            return BadRequest(ApiResponse<object>.Fail($"Settlement total ({totalSettled}) exceeds deposit paid ({depositPaid})."));

        var campId = 0;
        await using (var c2 = new SqlCommand("SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId=@CId", conn))
        { c2.Parameters.AddWithValue("@CId", req.ContractId); var v = await c2.ExecuteScalarAsync(); if (v != null) campId = (int)v; }

        // Adjust against rent dues
        if (req.AdjustAmount > 0)
        {
            await using var adj = new SqlCommand(@"
                INSERT INTO TxnRecords (TxnId, TxnType, ContractId, ContractCode, TenantId, CampId, TotalAmount, Amount,
                    PaidDate, Description, ReceivedBy, CreatedAt, UpdatedAt)
                VALUES (@TxnId, 'SD-ADJ', @CId, @CId, @TId, @CampId, @Amt, @Amt, GETDATE(), @Desc, @By, GETDATE(), GETDATE())", conn);
            adj.Parameters.AddWithValue("@TxnId", $"TXN-SD-ADJ-{DateTime.Now.Ticks % 1000000:D6}");
            adj.Parameters.AddWithValue("@CId", req.ContractId);
            adj.Parameters.AddWithValue("@TId", tenantId);
            adj.Parameters.AddWithValue("@CampId", campId);
            adj.Parameters.AddWithValue("@Amt", req.AdjustAmount);
            adj.Parameters.AddWithValue("@Desc", $"Security Deposit adjusted against rent dues - {req.Notes}");
            adj.Parameters.AddWithValue("@By", req.SettledBy);
            await adj.ExecuteNonQueryAsync();
        }

        // Refund to tenant
        if (req.RefundAmount > 0)
        {
            await using var ref2 = new SqlCommand(@"
                INSERT INTO TxnRecords (TxnId, TxnType, ContractId, ContractCode, TenantId, CampId, TotalAmount, Amount,
                    PaidDate, Description, ReceivedBy, FundPoolId, FundPoolName, CreatedAt, UpdatedAt)
                VALUES (@TxnId, 'SD-REF', @CId, @CId, @TId, @CampId, @Amt, @Amt, GETDATE(), @Desc, @By, @FpId, @FpName, GETDATE(), GETDATE())", conn);
            ref2.Parameters.AddWithValue("@TxnId", $"TXN-SD-REF-{DateTime.Now.Ticks % 1000000:D6}");
            ref2.Parameters.AddWithValue("@CId", req.ContractId);
            ref2.Parameters.AddWithValue("@TId", tenantId);
            ref2.Parameters.AddWithValue("@CampId", campId);
            ref2.Parameters.AddWithValue("@Amt", req.RefundAmount);
            ref2.Parameters.AddWithValue("@Desc", $"Security Deposit refunded to tenant - {req.Notes}");
            ref2.Parameters.AddWithValue("@By", req.SettledBy);
            ref2.Parameters.AddWithValue("@FpId", (object?)req.FundPoolId ?? DBNull.Value);
            ref2.Parameters.AddWithValue("@FpName", req.FundPoolName);
            await ref2.ExecuteNonQueryAsync();

            // Deduct from Fund Pool
            if (req.FundPoolId.HasValue)
            {
                await using var fp = new SqlCommand("UPDATE FundPools SET Balance = Balance - @Amt, UpdatedAt = GETDATE() WHERE Id = @Id", conn);
                fp.Parameters.AddWithValue("@Amt", req.RefundAmount);
                fp.Parameters.AddWithValue("@Id", req.FundPoolId.Value);
                await fp.ExecuteNonQueryAsync();
            }
        }

        // Forfeit (damage/penalty)
        if (req.ForfeitAmount > 0)
        {
            await using var frf = new SqlCommand(@"
                INSERT INTO TxnRecords (TxnId, TxnType, ContractId, ContractCode, TenantId, CampId, TotalAmount, Amount,
                    PaidDate, Description, ReceivedBy, CreatedAt, UpdatedAt)
                VALUES (@TxnId, 'SD-FRF', @CId, @CId, @TId, @CampId, @Amt, @Amt, GETDATE(), @Desc, @By, GETDATE(), GETDATE())", conn);
            frf.Parameters.AddWithValue("@TxnId", $"TXN-SD-FRF-{DateTime.Now.Ticks % 1000000:D6}");
            frf.Parameters.AddWithValue("@CId", req.ContractId);
            frf.Parameters.AddWithValue("@TId", tenantId);
            frf.Parameters.AddWithValue("@CampId", campId);
            frf.Parameters.AddWithValue("@Amt", req.ForfeitAmount);
            frf.Parameters.AddWithValue("@Desc", $"Security Deposit forfeited (damage/penalty) - {req.Notes}");
            frf.Parameters.AddWithValue("@By", req.SettledBy);
            await frf.ExecuteNonQueryAsync();
        }

        // Update contract status
        await using (var upd = new SqlCommand(@"
            UPDATE Contracts SET SecurityDepositStatus = @Status, UpdatedAt = GETDATE() WHERE ContractId = @CId", conn))
        {
            var status = req.RefundAmount > 0 ? "Refunded" : req.AdjustAmount > 0 ? "Adjusted" : "Forfeited";
            upd.Parameters.AddWithValue("@CId", req.ContractId);
            upd.Parameters.AddWithValue("@Status", status);
            await upd.ExecuteNonQueryAsync();
        }

        return Ok(ApiResponse<object>.Ok(new
        {
            contractId = req.ContractId,
            adjusted = req.AdjustAmount,
            refunded = req.RefundAmount,
            forfeited = req.ForfeitAmount,
            depositPaid,
        }, "Security deposit settled successfully."));
    }
}
