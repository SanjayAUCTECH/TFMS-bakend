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
public class OwnerDashboardController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public OwnerDashboardController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// GET api/ownerdashboard?ownerId=66
    /// Returns owner summary + recent transactions from OwnerTransactions table.
    /// DR = total amount (payable to owner)
    /// CR = total paid (already paid to owner)
    /// Due = DR - CR
    /// ownerId is optional.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? ownerId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetOwnerDashboard", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@OwnerId", (object?)ownerId ?? DBNull.Value);

        var result = new OwnerDashboardResponse();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Summary row ─────────────────────────────
        if (await reader.ReadAsync())
        {
            result.OwnerId         = reader.IsDBNull(reader.GetOrdinal("OwnerId"))         ? null : reader.GetInt32(reader.GetOrdinal("OwnerId"));
            result.OwnerCode       = reader.IsDBNull(reader.GetOrdinal("OwnerCode"))       ? "" : reader.GetString(reader.GetOrdinal("OwnerCode"));
            result.OwnerName       = reader.IsDBNull(reader.GetOrdinal("OwnerName"))       ? "" : reader.GetString(reader.GetOrdinal("OwnerName"));
            result.OwnerContact    = reader.IsDBNull(reader.GetOrdinal("OwnerContact"))    ? "" : reader.GetString(reader.GetOrdinal("OwnerContact"));
            result.OwnerEmail      = reader.IsDBNull(reader.GetOrdinal("OwnerEmail"))      ? "" : reader.GetString(reader.GetOrdinal("OwnerEmail"));
            result.OwnerStatus     = reader.IsDBNull(reader.GetOrdinal("OwnerStatus"))     ? "" : reader.GetString(reader.GetOrdinal("OwnerStatus"));
            result.TotalAmount     = reader.IsDBNull(reader.GetOrdinal("TotalAmount"))     ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalAmount"));
            result.TotalPaid       = reader.IsDBNull(reader.GetOrdinal("TotalPaid"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalPaid"));
            result.TotalDue        = reader.IsDBNull(reader.GetOrdinal("TotalDue"))        ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalDue"));
            result.ActiveContracts = reader.IsDBNull(reader.GetOrdinal("ActiveContracts")) ? 0 : reader.GetInt32(reader.GetOrdinal("ActiveContracts"));
            result.TotalContracts  = reader.IsDBNull(reader.GetOrdinal("TotalContracts"))  ? 0 : reader.GetInt32(reader.GetOrdinal("TotalContracts"));
        }

        // ── Result Set 2: Recent Transactions ─────────────────────
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.RecentTransactions.Add(new OwnerTxnItem
            {
                Id              = reader.GetInt32(reader.GetOrdinal("Id")),
                TxnCode         = reader.IsDBNull(reader.GetOrdinal("TxnCode"))        ? "" : reader.GetString(reader.GetOrdinal("TxnCode")),
                OwnerContractId = reader.IsDBNull(reader.GetOrdinal("OwnerContractId"))? 0  : reader.GetInt32(reader.GetOrdinal("OwnerContractId")),
                OcCode          = reader.IsDBNull(reader.GetOrdinal("OcCode"))         ? "" : reader.GetString(reader.GetOrdinal("OcCode")),
                OwnerId         = reader.IsDBNull(reader.GetOrdinal("OwnerId"))        ? 0  : reader.GetInt32(reader.GetOrdinal("OwnerId")),
                OwnerName       = reader.IsDBNull(reader.GetOrdinal("OwnerName"))      ? "" : reader.GetString(reader.GetOrdinal("OwnerName")),
                CampId          = reader.IsDBNull(reader.GetOrdinal("CampId"))         ? 0  : reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName        = reader.IsDBNull(reader.GetOrdinal("CampName"))       ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                TxnType         = reader.IsDBNull(reader.GetOrdinal("TxnType"))        ? "" : reader.GetString(reader.GetOrdinal("TxnType")),
                Amount          = reader.IsDBNull(reader.GetOrdinal("Amount"))         ? 0  : reader.GetDecimal(reader.GetOrdinal("Amount")),
                TxnDate         = reader.IsDBNull(reader.GetOrdinal("TxnDate"))        ? null : reader.GetString(reader.GetOrdinal("TxnDate")),
                Mode            = reader.IsDBNull(reader.GetOrdinal("Mode"))           ? "" : reader.GetString(reader.GetOrdinal("Mode")),
                Description     = reader.IsDBNull(reader.GetOrdinal("Description"))    ? "" : reader.GetString(reader.GetOrdinal("Description")),
                InstallmentNos  = reader.IsDBNull(reader.GetOrdinal("InstallmentNos")) ? "" : reader.GetString(reader.GetOrdinal("InstallmentNos")),
                ExpenseId       = reader.IsDBNull(reader.GetOrdinal("ExpenseId"))      ? null : reader.GetInt32(reader.GetOrdinal("ExpenseId")),
                CreatedAt       = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            });
        }

        return Ok(ApiResponse<OwnerDashboardResponse>.Ok(result, "Owner dashboard retrieved."));
    }
}
