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

        return Ok(ApiResponse<object>.Ok(new
        {
            contractId     = req.ContractId,
            amountReceived = req.Amount,
            totalPaid      = newPaid,
            status         = newStatus,
        }, $"Security deposit of {req.Amount} received. Status: {newStatus}"));
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
