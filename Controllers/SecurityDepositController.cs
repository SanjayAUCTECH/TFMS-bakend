using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SecurityDepositController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;
    public SecurityDepositController(IDbConnectionFactory factory, IActivityLogService log)
    {
        _factory     = factory;
        _activityLog = log;
    }

    // ─────────────────────────────────────────────────────────────────────────
    /// <summary>GET api/securitydeposit/status/{contractId}</summary>
    [HttpGet("status/{contractId}")]
    public async Task<IActionResult> GetStatus(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSecurityDepositStatus", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
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

    // ─────────────────────────────────────────────────────────────────────────
    /// <summary>POST api/securitydeposit/receive — Receive security deposit from tenant</summary>
    [HttpPost("receive")]
    public async Task<IActionResult> Receive([FromBody] ReceiveSecurityDepositRequest req)
    {
        if (string.IsNullOrEmpty(req.ContractId))
            return BadRequest(ApiResponse<object>.Fail("ContractId required."));
        if (req.Amount <= 0)
            return BadRequest(ApiResponse<object>.Fail("Amount must be greater than 0."));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_ReceiveSecurityDeposit", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@ContractId",    req.ContractId);
        cmd.Parameters.AddWithValue("@Amount",        req.Amount);
        cmd.Parameters.AddWithValue("@PaidDate",      req.PaidDate);
        cmd.Parameters.AddWithValue("@PaymentMode",   req.PaymentMode);
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)req.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ChequeNumber",  req.ChequeNumber ?? "");
        cmd.Parameters.AddWithValue("@FundPoolId",    (object?)req.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",  req.FundPoolName ?? "");
        cmd.Parameters.AddWithValue("@ReceivedBy",    req.ReceivedBy ?? "Admin");
        cmd.Parameters.AddWithValue("@Notes",         req.Notes ?? "");

        var pNewPaid   = new SqlParameter("@NewPaid",   SqlDbType.Decimal) { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };
        var pNewStatus = new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pNewPaid);
        cmd.Parameters.Add(pNewStatus);

        await cmd.ExecuteNonQueryAsync();

        var newPaid   = (decimal)pNewPaid.Value;
        var newStatus = pNewStatus.Value?.ToString() ?? "Received";

        // ★ Sync to AccountMasters (Nature='Camp')
        await using (var syncCmd = new SqlCommand("sp_SyncSDReceiveToAccountMaster", conn) { CommandType = CommandType.StoredProcedure })
        {
            syncCmd.Parameters.AddWithValue("@ContractId", req.ContractId);
            syncCmd.Parameters.AddWithValue("@Amount", req.Amount);
            syncCmd.Parameters.AddWithValue("@PaidDate", req.PaidDate);
            syncCmd.Parameters.AddWithValue("@PaymentMode", req.PaymentMode);
            syncCmd.Parameters.AddWithValue("@FundPoolId", (object?)req.FundPoolId ?? DBNull.Value);
            await syncCmd.ExecuteNonQueryAsync();
        }

        await Log(ActivityType.Insert, ActivityModule.SecurityDeposit,
            $"SD Received: Contract {req.ContractId}, Amount {req.Amount}, Mode {req.PaymentMode}, Status {newStatus}",
            req.ContractId, "SecurityDeposit");

        return Ok(ApiResponse<object>.Ok(new
        {
            contractId     = req.ContractId,
            amountReceived = req.Amount,
            totalPaid      = newPaid,
            status         = newStatus,
        }, $"Security deposit of {req.Amount} received. Status: {newStatus}"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    /// <summary>
    /// DELETE api/securitydeposit/receive/{txnRecordId}
    /// Deletes ONE received SD entry and reverts all updates/inserts:
    ///   Contracts (paid/status), FundPools (balance), ContractRooms (paid/due)
    ///   TxnRecords, Incomes, ContractRoomsTrns — all soft-deleted.
    /// </summary>
    [HttpDelete("receive/{txnRecordId:int}")]
    public async Task<IActionResult> DeleteReceived(int txnRecordId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteSecurityDeposit", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 60
        };
        cmd.Parameters.AddWithValue("@TxnRecordId", txnRecordId);
        cmd.Parameters.AddWithValue("@DeletedBy",   CurrentUserId == 0 ? DBNull.Value : (object)CurrentUserId);

        var newPaidParam = new SqlParameter("@NewPaid", SqlDbType.Decimal)
            { Precision = 18, Scale = 2, Direction = ParameterDirection.Output };
        var newStatusParam = new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newPaidParam);
        cmd.Parameters.Add(newStatusParam);

        try
        {
            await cmd.ExecuteNonQueryAsync();
        }
        catch (SqlException ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }

        var newPaid   = newPaidParam.Value   == DBNull.Value ? 0m : (decimal)newPaidParam.Value;
        var newStatus = newStatusParam.Value == DBNull.Value ? "" : (string)newStatusParam.Value;

        await Log(ActivityType.Delete, ActivityModule.SecurityDeposit,
            $"SD Receipt deleted: TxnRecordId {txnRecordId}, reverted. New status {newStatus}",
            txnRecordId.ToString(), "SecurityDeposit");

        return Ok(ApiResponse<object>.Ok(new
        {
            txnRecordId,
            totalPaid = newPaid,
            status    = newStatus,
        }, $"Security deposit receipt deleted and reverted. Status: {newStatus}"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    /// <summary>POST api/securitydeposit/settle — Settle deposit (adjust / refund / forfeit)</summary>
    [HttpPost("settle")]
    public async Task<IActionResult> Settle([FromBody] SettleSecurityDepositRequest req)
    {
        if (string.IsNullOrEmpty(req.ContractId))
            return BadRequest(ApiResponse<object>.Fail("ContractId required."));

        var totalSettled = req.AdjustAmount + req.RefundAmount + req.ForfeitAmount;
        if (totalSettled <= 0)
            return BadRequest(ApiResponse<object>.Fail("At least one of AdjustAmount, RefundAmount, or ForfeitAmount must be > 0."));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_SettleSecurityDeposit", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@ContractId",    req.ContractId);
        cmd.Parameters.AddWithValue("@AdjustAmount",  req.AdjustAmount);
        cmd.Parameters.AddWithValue("@RefundAmount",  req.RefundAmount);
        cmd.Parameters.AddWithValue("@ForfeitAmount", req.ForfeitAmount);
        cmd.Parameters.AddWithValue("@FundPoolId",    (object?)req.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",  req.FundPoolName ?? "");
        cmd.Parameters.AddWithValue("@Notes",         req.Notes ?? "");
        cmd.Parameters.AddWithValue("@SettledBy",     req.SettledBy ?? "Admin");

        var pNewStatus = new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pNewStatus);

        await cmd.ExecuteNonQueryAsync();

        var newStatus = pNewStatus.Value?.ToString() ?? "Settled";

        // ★ Sync to AccountMasters — Refund case
        if (req.RefundAmount > 0)
        {
            await using var syncCmd = new SqlCommand("sp_SyncSDRefundToAccountMaster", conn) { CommandType = CommandType.StoredProcedure };
            syncCmd.Parameters.AddWithValue("@ContractId", req.ContractId);
            syncCmd.Parameters.AddWithValue("@Amount", req.RefundAmount);
            await syncCmd.ExecuteNonQueryAsync();
        }

        // ★ Sync to AccountMasters — Forfeit/Penalty case
        if (req.ForfeitAmount > 0)
        {
            await using var syncCmd = new SqlCommand("sp_SyncSDForfeitToAccountMaster", conn) { CommandType = CommandType.StoredProcedure };
            syncCmd.Parameters.AddWithValue("@ContractId", req.ContractId);
            syncCmd.Parameters.AddWithValue("@ForfeitAmount", req.ForfeitAmount);
            syncCmd.Parameters.AddWithValue("@FundPoolId", (object?)req.FundPoolId ?? DBNull.Value);
            syncCmd.Parameters.AddWithValue("@FundPoolName", req.FundPoolName ?? "");
            await syncCmd.ExecuteNonQueryAsync();
        }

        await Log(ActivityType.Update, ActivityModule.SecurityDeposit,
            $"SD Settled: Contract {req.ContractId}, Adjust {req.AdjustAmount}, Refund {req.RefundAmount}, Forfeit {req.ForfeitAmount}, Status {newStatus}",
            req.ContractId, "SecurityDeposit");

        return Ok(ApiResponse<object>.Ok(new
        {
            contractId   = req.ContractId,
            adjusted     = req.AdjustAmount,
            refunded     = req.RefundAmount,
            forfeited    = req.ForfeitAmount,
            totalSettled,
            newStatus,
        }, "Security deposit settled successfully."));
    }
}
