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
public class PartnerDashboardController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public PartnerDashboardController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// GET api/partnerdashboard?partnerId=69
    /// Returns partner summary, assigned camps, and recent income+expense transactions.
    /// partnerId is optional.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? partnerId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetPartnerDashboard", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PartnerId", (object?)partnerId ?? DBNull.Value);

        var result = new PartnerDashboardResponse();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Summary ─────────────────────────────────
        if (await reader.ReadAsync())
        {
            result.PartnerId      = reader.IsDBNull(reader.GetOrdinal("PartnerId"))      ? null : reader.GetInt32(reader.GetOrdinal("PartnerId"));
            result.PartnerName    = reader.IsDBNull(reader.GetOrdinal("PartnerName"))    ? "" : reader.GetString(reader.GetOrdinal("PartnerName"));
            result.PartnerCode    = reader.IsDBNull(reader.GetOrdinal("PartnerCode"))    ? "" : reader.GetString(reader.GetOrdinal("PartnerCode"));
            result.PartnerContact = reader.IsDBNull(reader.GetOrdinal("PartnerContact")) ? "" : reader.GetString(reader.GetOrdinal("PartnerContact"));
            result.PartnerEmail   = reader.IsDBNull(reader.GetOrdinal("PartnerEmail"))   ? "" : reader.GetString(reader.GetOrdinal("PartnerEmail"));
            result.PartnerStatus  = reader.IsDBNull(reader.GetOrdinal("PartnerStatus"))  ? "" : reader.GetString(reader.GetOrdinal("PartnerStatus"));
            result.TotalIncome    = reader.IsDBNull(reader.GetOrdinal("TotalIncome"))    ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalIncome"));
            result.TotalExpense   = reader.IsDBNull(reader.GetOrdinal("TotalExpense"))   ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalExpense"));
            result.NetBalance     = reader.IsDBNull(reader.GetOrdinal("NetBalance"))     ? 0 : reader.GetDecimal(reader.GetOrdinal("NetBalance"));
            result.AssignedCamps  = reader.IsDBNull(reader.GetOrdinal("AssignedCamps"))  ? 0 : reader.GetInt32(reader.GetOrdinal("AssignedCamps"));
            result.TotalRooms     = reader.IsDBNull(reader.GetOrdinal("TotalRooms"))     ? 0 : reader.GetInt32(reader.GetOrdinal("TotalRooms"));
            result.OccupiedRooms  = reader.IsDBNull(reader.GetOrdinal("OccupiedRooms"))  ? 0 : reader.GetInt32(reader.GetOrdinal("OccupiedRooms"));
            result.VacantRooms    = reader.IsDBNull(reader.GetOrdinal("VacantRooms"))    ? 0 : reader.GetInt32(reader.GetOrdinal("VacantRooms"));

            // Wallet / Payout fields
            result.OpeningBalance     = reader.IsDBNull(reader.GetOrdinal("OpeningBalance"))     ? 0 : reader.GetDecimal(reader.GetOrdinal("OpeningBalance"));
            result.ProfitGenerate     = reader.IsDBNull(reader.GetOrdinal("ProfitGenerate"))     ? 0 : reader.GetDecimal(reader.GetOrdinal("ProfitGenerate"));
            result.ProfitGenerateDate = reader.IsDBNull(reader.GetOrdinal("ProfitGenerateDate")) ? null : reader.GetDateTime(reader.GetOrdinal("ProfitGenerateDate"));
            result.TotalOPAmount      = reader.IsDBNull(reader.GetOrdinal("TotalOPAmount"))      ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalOPAmount"));
            result.Paid               = reader.IsDBNull(reader.GetOrdinal("Paid"))               ? 0 : reader.GetDecimal(reader.GetOrdinal("Paid"));
            result.ClosingBalance     = reader.IsDBNull(reader.GetOrdinal("ClosingBalance"))     ? 0 : reader.GetDecimal(reader.GetOrdinal("ClosingBalance"));
            result.TotalProfit        = reader.IsDBNull(reader.GetOrdinal("TotalProfit"))        ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalProfit"));
            result.TotalReceived      = reader.IsDBNull(reader.GetOrdinal("TotalReceived"))      ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalReceived"));
            result.TotalBalance       = reader.IsDBNull(reader.GetOrdinal("TotalBalance"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalBalance"));
        }

        // ── Result Set 2: Assigned Camps ──────────────────────────
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.Camps.Add(new PartnerCampItem
            {
                PartnerId     = reader.IsDBNull(reader.GetOrdinal("PartnerId"))     ? 0  : reader.GetInt32(reader.GetOrdinal("PartnerId")),
                CampId        = reader.IsDBNull(reader.GetOrdinal("CampId"))        ? 0  : reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName      = reader.IsDBNull(reader.GetOrdinal("CampName"))      ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                CampCode      = reader.IsDBNull(reader.GetOrdinal("CampCode"))      ? "" : reader.GetString(reader.GetOrdinal("CampCode")),
                ShareType     = reader.IsDBNull(reader.GetOrdinal("ShareType"))     ? "" : reader.GetString(reader.GetOrdinal("ShareType")),
                ShareValue    = reader.IsDBNull(reader.GetOrdinal("ShareValue"))    ? 0  : reader.GetDecimal(reader.GetOrdinal("ShareValue")),
                CampStatus    = reader.IsDBNull(reader.GetOrdinal("CampStatus"))    ? "" : reader.GetString(reader.GetOrdinal("CampStatus")),
                FromDate      = reader.IsDBNull(reader.GetOrdinal("FromDate"))      ? null : reader.GetString(reader.GetOrdinal("FromDate")),
                ToDate        = reader.IsDBNull(reader.GetOrdinal("ToDate"))        ? null : reader.GetString(reader.GetOrdinal("ToDate")),
                TotalRooms    = reader.IsDBNull(reader.GetOrdinal("TotalRooms"))    ? 0  : reader.GetInt32(reader.GetOrdinal("TotalRooms")),
                OccupiedRooms = reader.IsDBNull(reader.GetOrdinal("OccupiedRooms")) ? 0  : reader.GetInt32(reader.GetOrdinal("OccupiedRooms")),
                VacantRooms   = reader.IsDBNull(reader.GetOrdinal("VacantRooms"))   ? 0  : reader.GetInt32(reader.GetOrdinal("VacantRooms")),
            });
        }

        // ── Result Set 3: Recent Transactions ─────────────────────
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.RecentTransactions.Add(new PartnerTxnItem
            {
                TxnType      = reader.IsDBNull(reader.GetOrdinal("TxnType"))      ? "" : reader.GetString(reader.GetOrdinal("TxnType")),
                TxnRefId     = reader.IsDBNull(reader.GetOrdinal("TxnRefId"))     ? "" : reader.GetString(reader.GetOrdinal("TxnRefId")),
                Date         = reader.IsDBNull(reader.GetOrdinal("Date"))         ? null : reader.GetDateTime(reader.GetOrdinal("Date")).ToString("yyyy-MM-dd"),
                Amount       = reader.IsDBNull(reader.GetOrdinal("Amount"))       ? 0  : reader.GetDecimal(reader.GetOrdinal("Amount")),
                Head         = reader.IsDBNull(reader.GetOrdinal("Head"))         ? "" : reader.GetString(reader.GetOrdinal("Head")),
                Mode         = reader.IsDBNull(reader.GetOrdinal("Mode"))         ? "" : reader.GetString(reader.GetOrdinal("Mode")),
                FundPoolName = reader.IsDBNull(reader.GetOrdinal("FundPoolName")) ? "" : reader.GetString(reader.GetOrdinal("FundPoolName")),
                Purpose      = reader.IsDBNull(reader.GetOrdinal("Purpose"))      ? "" : reader.GetString(reader.GetOrdinal("Purpose")),
                CampId       = reader.IsDBNull(reader.GetOrdinal("CampId"))       ? 0  : reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName     = reader.IsDBNull(reader.GetOrdinal("CampName"))     ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                CreatedAt    = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            });
        }

        return Ok(ApiResponse<PartnerDashboardResponse>.Ok(result, "Partner dashboard retrieved."));
    }
}
