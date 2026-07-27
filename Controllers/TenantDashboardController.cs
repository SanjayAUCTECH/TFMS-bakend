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
public class TenantDashboardController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public TenantDashboardController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// GET api/tenantdashboard?tenantId=49
    /// Returns tenant summary + recent transactions.
    /// tenantId is optional — if omitted returns aggregate for all tenants.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? tenantId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetTenantDashboard", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@TenantId", (object?)tenantId ?? DBNull.Value);

        var result = new TenantDashboardResponse();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Summary row ────────────────────────────
        if (await reader.ReadAsync())
        {
            result.TotalAmount          = reader.IsDBNull(reader.GetOrdinal("TotalAmount"))          ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalAmount"));
            result.TotalPaid            = reader.IsDBNull(reader.GetOrdinal("TotalPaid"))            ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalPaid"));
            result.TotalDue             = reader.IsDBNull(reader.GetOrdinal("TotalDue"))             ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalDue"));
            result.SecurityPaidAmount   = reader.IsDBNull(reader.GetOrdinal("SecurityPaidAmount"))   ? 0 : reader.GetDecimal(reader.GetOrdinal("SecurityPaidAmount"));
            result.TotalSecurityAmount  = reader.IsDBNull(reader.GetOrdinal("TotalSecurityAmount"))  ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalSecurityAmount"));
            result.SecurityDueAmount    = reader.IsDBNull(reader.GetOrdinal("SecurityDueAmount"))    ? 0 : reader.GetDecimal(reader.GetOrdinal("SecurityDueAmount"));
            result.PenaltyAmount        = reader.IsDBNull(reader.GetOrdinal("PenaltyAmount"))        ? 0 : reader.GetDecimal(reader.GetOrdinal("PenaltyAmount"));
            result.RefundAmount         = reader.IsDBNull(reader.GetOrdinal("RefundAmount"))         ? 0 : reader.GetDecimal(reader.GetOrdinal("RefundAmount"));
            result.TenantId             = reader.IsDBNull(reader.GetOrdinal("TenantId"))             ? null : reader.GetInt32(reader.GetOrdinal("TenantId"));
            result.TenantName           = reader.IsDBNull(reader.GetOrdinal("TenantName"))           ? "" : reader.GetString(reader.GetOrdinal("TenantName"));
            result.TenantContact        = reader.IsDBNull(reader.GetOrdinal("TenantContact"))        ? "" : reader.GetString(reader.GetOrdinal("TenantContact"));
            result.TenantEmail          = reader.IsDBNull(reader.GetOrdinal("TenantEmail"))          ? "" : reader.GetString(reader.GetOrdinal("TenantEmail"));
            result.TenantStatus         = reader.IsDBNull(reader.GetOrdinal("TenantStatus"))         ? "" : reader.GetString(reader.GetOrdinal("TenantStatus"));
        }

        // ── Result Set 2: Recent Transactions ───────────────────
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.RecentTransactions.Add(new TenantTxnItem
            {
                Id                  = reader.GetInt32(reader.GetOrdinal("Id")),
                TxnId               = reader.IsDBNull(reader.GetOrdinal("TxnId"))               ? "" : reader.GetString(reader.GetOrdinal("TxnId")),
                TxnType             = reader.IsDBNull(reader.GetOrdinal("TxnType"))             ? "" : reader.GetString(reader.GetOrdinal("TxnType")),
                ContractId          = reader.IsDBNull(reader.GetOrdinal("ContractId"))          ? "" : reader.GetString(reader.GetOrdinal("ContractId")),
                ContractCode        = reader.IsDBNull(reader.GetOrdinal("ContractCode"))        ? "" : reader.GetString(reader.GetOrdinal("ContractCode")),
                TenantId            = reader.IsDBNull(reader.GetOrdinal("TenantId"))            ? 0  : reader.GetInt32(reader.GetOrdinal("TenantId")),
                TenantName          = reader.IsDBNull(reader.GetOrdinal("TenantName"))          ? "" : reader.GetString(reader.GetOrdinal("TenantName")),
                CampId              = reader.IsDBNull(reader.GetOrdinal("CampId"))              ? 0  : reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName            = reader.IsDBNull(reader.GetOrdinal("CampName"))            ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                TotalAmount         = reader.IsDBNull(reader.GetOrdinal("TotalAmount"))         ? 0  : reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                Amount              = reader.IsDBNull(reader.GetOrdinal("Amount"))              ? 0  : reader.GetDecimal(reader.GetOrdinal("Amount")),
                TxnDate             = reader.IsDBNull(reader.GetOrdinal("TxnDate"))             ? null : reader.GetString(reader.GetOrdinal("TxnDate")),
                PaymentMode         = reader.IsDBNull(reader.GetOrdinal("PaymentMode"))         ? "" : reader.GetString(reader.GetOrdinal("PaymentMode")),
                PaymentModeId       = reader.IsDBNull(reader.GetOrdinal("PaymentModeId"))       ? null : reader.GetInt32(reader.GetOrdinal("PaymentModeId")),
                ChequeNumber        = reader.IsDBNull(reader.GetOrdinal("ChequeNumber"))        ? "" : reader.GetString(reader.GetOrdinal("ChequeNumber")),
                Description         = reader.IsDBNull(reader.GetOrdinal("Description"))        ? "" : reader.GetString(reader.GetOrdinal("Description")),
                ReceivedBy          = reader.IsDBNull(reader.GetOrdinal("ReceivedBy"))          ? "" : reader.GetString(reader.GetOrdinal("ReceivedBy")),
                FundPoolName        = reader.IsDBNull(reader.GetOrdinal("FundPoolName"))        ? "" : reader.GetString(reader.GetOrdinal("FundPoolName")),
                AppliedInstallments = reader.IsDBNull(reader.GetOrdinal("AppliedInstallments")) ? "" : reader.GetString(reader.GetOrdinal("AppliedInstallments")),
                InstallmentNo       = reader.IsDBNull(reader.GetOrdinal("InstallmentNo"))       ? null : reader.GetInt32(reader.GetOrdinal("InstallmentNo")),
                Unallocated         = reader.IsDBNull(reader.GetOrdinal("Unallocated"))         ? 0  : reader.GetDecimal(reader.GetOrdinal("Unallocated")),
                CreatedAt           = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            });
        }

        return Ok(ApiResponse<TenantDashboardResponse>.Ok(result, "Tenant dashboard retrieved."));
    }
}
