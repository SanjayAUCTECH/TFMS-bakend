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
public class OtherPersonDashboardController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public OtherPersonDashboardController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// GET api/otherpersondashboard?personId=34
    /// Returns OtherPerson summary + recent transactions from Expenses table.
    /// Company expense to OtherPerson = Credit for OtherPerson (same as Staff).
    /// personId is optional.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? personId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetOtherPersonDashboard", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PersonId", (object?)personId ?? DBNull.Value);

        var result = new OtherPersonDashboardResponse();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Summary row ─────────────────────────────
        if (await reader.ReadAsync())
        {
            result.PersonId          = reader.IsDBNull(reader.GetOrdinal("PersonId"))          ? null : reader.GetInt32(reader.GetOrdinal("PersonId"));
            result.PersonCode        = reader.IsDBNull(reader.GetOrdinal("PersonCode"))        ? "" : reader.GetString(reader.GetOrdinal("PersonCode"));
            result.PersonName        = reader.IsDBNull(reader.GetOrdinal("PersonName"))        ? "" : reader.GetString(reader.GetOrdinal("PersonName"));
            result.Designation       = reader.IsDBNull(reader.GetOrdinal("Designation"))       ? "" : reader.GetString(reader.GetOrdinal("Designation"));
            result.Mobile            = reader.IsDBNull(reader.GetOrdinal("Mobile"))            ? "" : reader.GetString(reader.GetOrdinal("Mobile"));
            result.Email             = reader.IsDBNull(reader.GetOrdinal("Email"))             ? "" : reader.GetString(reader.GetOrdinal("Email"));
            result.Address           = reader.IsDBNull(reader.GetOrdinal("Address"))           ? "" : reader.GetString(reader.GetOrdinal("Address"));
            result.Status            = reader.IsDBNull(reader.GetOrdinal("Status"))            ? "" : reader.GetString(reader.GetOrdinal("Status"));
            result.TotalIncome       = reader.IsDBNull(reader.GetOrdinal("TotalIncome"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalIncome"));
            result.TotalTransactions = reader.IsDBNull(reader.GetOrdinal("TotalTransactions")) ? 0 : reader.GetInt32(reader.GetOrdinal("TotalTransactions"));
        }

        // ── Result Set 2: Recent Transactions ─────────────────────
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.RecentTransactions.Add(new OtherPersonTxnItem
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

        return Ok(ApiResponse<OtherPersonDashboardResponse>.Ok(result, "Other person dashboard retrieved."));
    }
}
