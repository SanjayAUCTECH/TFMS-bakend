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
public class StaffDashboardController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public StaffDashboardController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// GET api/staffdashboard?staffId=5
    /// Returns staff summary + recent transactions from Expenses table
    /// (company expense = staff credit/income).
    /// staffId is optional — if omitted returns aggregate for all staff.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? staffId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetStaffDashboard", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@StaffId", (object?)staffId ?? DBNull.Value);

        var result = new StaffDashboardResponse();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Summary row ─────────────────────────────
        if (await reader.ReadAsync())
        {
            result.StaffId          = reader.IsDBNull(reader.GetOrdinal("StaffId"))     ? null : reader.GetInt32(reader.GetOrdinal("StaffId"));
            result.StaffCode        = reader.IsDBNull(reader.GetOrdinal("StaffCode"))   ? "" : reader.GetString(reader.GetOrdinal("StaffCode"));
            result.StaffName        = reader.IsDBNull(reader.GetOrdinal("StaffName"))   ? "" : reader.GetString(reader.GetOrdinal("StaffName"));
            result.Role             = reader.IsDBNull(reader.GetOrdinal("Role"))        ? "" : reader.GetString(reader.GetOrdinal("Role"));
            result.Designation      = reader.IsDBNull(reader.GetOrdinal("Designation")) ? "" : reader.GetString(reader.GetOrdinal("Designation"));
            result.JobTitle         = reader.IsDBNull(reader.GetOrdinal("JobTitle"))    ? "" : reader.GetString(reader.GetOrdinal("JobTitle"));
            result.Contact          = reader.IsDBNull(reader.GetOrdinal("Contact"))     ? "" : reader.GetString(reader.GetOrdinal("Contact"));
            result.Email            = reader.IsDBNull(reader.GetOrdinal("Email"))       ? "" : reader.GetString(reader.GetOrdinal("Email"));
            result.Status           = reader.IsDBNull(reader.GetOrdinal("Status"))      ? "" : reader.GetString(reader.GetOrdinal("Status"));
            result.TotalIncome      = reader.IsDBNull(reader.GetOrdinal("TotalIncome")) ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalIncome"));
            result.TotalTransactions = reader.IsDBNull(reader.GetOrdinal("TotalTransactions")) ? 0 : reader.GetInt32(reader.GetOrdinal("TotalTransactions"));
        }

        // ── Result Set 2: Recent Transactions ─────────────────────
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.RecentTransactions.Add(new StaffTxnItem
            {
                Id            = reader.GetInt32(reader.GetOrdinal("Id")),
                TxnRefId      = reader.IsDBNull(reader.GetOrdinal("TxnRefId"))      ? "" : reader.GetString(reader.GetOrdinal("TxnRefId")),
                TxnType       = reader.IsDBNull(reader.GetOrdinal("TxnType"))       ? "Credit" : reader.GetString(reader.GetOrdinal("TxnType")),
                Date          = reader.IsDBNull(reader.GetOrdinal("Date"))          ? null : reader.GetString(reader.GetOrdinal("Date")),
                Amount        = reader.IsDBNull(reader.GetOrdinal("Amount"))        ? 0 : reader.GetDecimal(reader.GetOrdinal("Amount")),
                Head          = reader.IsDBNull(reader.GetOrdinal("Head"))          ? "" : reader.GetString(reader.GetOrdinal("Head")),
                Mode          = reader.IsDBNull(reader.GetOrdinal("Mode"))          ? "" : reader.GetString(reader.GetOrdinal("Mode")),
                FundPoolName  = reader.IsDBNull(reader.GetOrdinal("FundPoolName"))  ? "" : reader.GetString(reader.GetOrdinal("FundPoolName")),
                Purpose       = reader.IsDBNull(reader.GetOrdinal("Purpose"))       ? "" : reader.GetString(reader.GetOrdinal("Purpose")),
                CampId        = reader.IsDBNull(reader.GetOrdinal("CampId"))        ? 0  : reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName      = reader.IsDBNull(reader.GetOrdinal("CampName"))      ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                RecipientId   = reader.IsDBNull(reader.GetOrdinal("RecipientId"))   ? 0  : reader.GetInt32(reader.GetOrdinal("RecipientId")),
                RecipientName = reader.IsDBNull(reader.GetOrdinal("RecipientName")) ? "" : reader.GetString(reader.GetOrdinal("RecipientName")),
                CreatedAt     = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            });
        }

        return Ok(ApiResponse<StaffDashboardResponse>.Ok(result, "Staff dashboard retrieved."));
    }
}
