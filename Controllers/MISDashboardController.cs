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
public class MISDashboardController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;

    public MISDashboardController(IDbConnectionFactory factory)
        => _factory = factory;

    /// <summary>
    /// GET /api/MISDashboard?month=2026-07&amp;campId=1
    /// Returns:
    ///   cards           → TotalCollection, TotalExpense, TotalUnits, TotalOccupied, TotalVacant
    ///   collectionData  → per-camp: NetUnits, Occupied, Vacant, AvgRent, Rental, Collected,
    ///                                Discount, Balance, ReceivedSD, GrandTotal
    ///   expenseData     → per-category pivot: Category, Total, {campName: amount, ...}
    ///   campNames       → dynamic camp column list (for expense table headers)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] MISDashboardRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetMISDashboard", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 120
        };
        cmd.Parameters.AddWithValue("@CampId", (object?)request.CampId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",  string.IsNullOrWhiteSpace(request.Month)
                                                    ? DBNull.Value
                                                    : (object)request.Month.Trim());

        var response = new MISDashboardResponse();
        var expenseDetails      = new List<MISExpenseDetailRow>();
        var expenseCategoryMap  = new Dictionary<string, decimal>();   // RS2: category → total
        var partnerDetails      = new List<(int PartnerId, string PartnerName, string CampName, decimal ShareAmount)>();

        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            // ── RS1: Collection per camp ──────────────────────────────
            while (await rd.ReadAsync())
            {
                var collected  = rd.IsDBNull(rd.GetOrdinal("Collected"))  ? 0m : rd.GetDecimal(rd.GetOrdinal("Collected"));
                var receivedSd = rd.IsDBNull(rd.GetOrdinal("ReceivedSD")) ? 0m : rd.GetDecimal(rd.GetOrdinal("ReceivedSD"));
                response.CollectionData.Add(new MISCollectionRow
                {
                    CampId     = rd.IsDBNull(rd.GetOrdinal("CampId"))   ? 0  : rd.GetInt32(rd.GetOrdinal("CampId")),
                    CampCode   = rd.IsDBNull(rd.GetOrdinal("CampCode")) ? "" : rd.GetString(rd.GetOrdinal("CampCode")),
                    CampName   = rd.IsDBNull(rd.GetOrdinal("CampName")) ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    NetUnits   = rd.IsDBNull(rd.GetOrdinal("NetUnits"))  ? 0  : rd.GetInt32(rd.GetOrdinal("NetUnits")),
                    Occupied   = rd.IsDBNull(rd.GetOrdinal("Occupied"))  ? 0  : rd.GetInt32(rd.GetOrdinal("Occupied")),
                    Vacant     = rd.IsDBNull(rd.GetOrdinal("Vacant"))    ? 0  : rd.GetInt32(rd.GetOrdinal("Vacant")),
                    AvgRent    = rd.IsDBNull(rd.GetOrdinal("AvgRent"))   ? 0m : rd.GetDecimal(rd.GetOrdinal("AvgRent")),
                    Rental     = rd.IsDBNull(rd.GetOrdinal("Rental"))    ? 0m : rd.GetDecimal(rd.GetOrdinal("Rental")),
                    Collected  = collected,
                    Discount   = rd.IsDBNull(rd.GetOrdinal("Discount"))  ? 0m : rd.GetDecimal(rd.GetOrdinal("Discount")),
                    Balance    = rd.IsDBNull(rd.GetOrdinal("Balance"))   ? 0m : rd.GetDecimal(rd.GetOrdinal("Balance")),
                    ReceivedSD = receivedSd,
                });
            }

            // ── RS2: Expense categories (totals only) ─────────────────
            await rd.NextResultAsync();
            while (await rd.ReadAsync())
            {
                var cat = rd.IsDBNull(rd.GetOrdinal("Category")) ? "" : rd.GetString(rd.GetOrdinal("Category"));
                var tot = rd.IsDBNull(rd.GetOrdinal("Total"))    ? 0m : rd.GetDecimal(rd.GetOrdinal("Total"));
                expenseCategoryMap[cat] = tot;
            }

            // ── RS3: Expense detail per camp per category ─────────────
            await rd.NextResultAsync();
            while (await rd.ReadAsync())
            {
                expenseDetails.Add(new MISExpenseDetailRow
                {
                    Category = rd.IsDBNull(rd.GetOrdinal("Category")) ? "" : rd.GetString(rd.GetOrdinal("Category")),
                    CampId   = rd.IsDBNull(rd.GetOrdinal("CampId"))   ? null : rd.GetInt32(rd.GetOrdinal("CampId")),
                    CampName = rd.IsDBNull(rd.GetOrdinal("CampName")) ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    Amount   = rd.IsDBNull(rd.GetOrdinal("Amount"))   ? 0m : rd.GetDecimal(rd.GetOrdinal("Amount")),
                });
            }

            // ── RS4: Summary cards ────────────────────────────────────
            await rd.NextResultAsync();
            if (await rd.ReadAsync())
            {
                response.Cards = new MISDashboardCards
                {
                    TotalCollection = rd.IsDBNull(rd.GetOrdinal("TotalCollection")) ? 0m : rd.GetDecimal(rd.GetOrdinal("TotalCollection")),
                    TotalExpense    = rd.IsDBNull(rd.GetOrdinal("TotalExpense"))    ? 0m : rd.GetDecimal(rd.GetOrdinal("TotalExpense")),
                    TotalUnits      = rd.IsDBNull(rd.GetOrdinal("TotalUnits"))      ? 0  : rd.GetInt32(rd.GetOrdinal("TotalUnits")),
                    TotalOccupied   = rd.IsDBNull(rd.GetOrdinal("TotalOccupied"))   ? 0  : rd.GetInt32(rd.GetOrdinal("TotalOccupied")),
                    TotalVacant     = rd.IsDBNull(rd.GetOrdinal("TotalVacant"))     ? 0  : rd.GetInt32(rd.GetOrdinal("TotalVacant")),
                };
            }

            // ── RS5: Partner profit from Expenses (RecipientRole='Partner', Head='Partner Profit') ──
            await rd.NextResultAsync();
            while (await rd.ReadAsync())
            {
                partnerDetails.Add((
                    PartnerId:   rd.IsDBNull(rd.GetOrdinal("PartnerId"))   ? 0  : rd.GetInt32(rd.GetOrdinal("PartnerId")),
                    PartnerName: rd.IsDBNull(rd.GetOrdinal("PartnerName")) ? "" : rd.GetString(rd.GetOrdinal("PartnerName")),
                    CampName:    rd.IsDBNull(rd.GetOrdinal("CampName"))    ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    ShareAmount: rd.IsDBNull(rd.GetOrdinal("Amount"))      ? 0m : rd.GetDecimal(rd.GetOrdinal("Amount"))
                ));
            }
        }

        // ── Build pivot expense rows (category × camp) ────────────────
        response.CampNames = expenseDetails
            .Where(x => !string.IsNullOrEmpty(x.CampName))
            .Select(x => x.CampName)
            .Distinct()
            .OrderBy(x => x)
            .ToList();

        // Use RS2 category map as base — ensures ALL categories appear (even those with no camp breakdown)
        foreach (var kvp in expenseCategoryMap)
        {
            var cat     = kvp.Key;
            var total   = kvp.Value;
            var details = expenseDetails.Where(x => x.Category == cat).ToList();

            var pivotRow = new MISExpensePivotRow
            {
                Category = cat,
                Total    = total,
            };
            foreach (var detail in details)
            {
                if (!string.IsNullOrEmpty(detail.CampName))
                    pivotRow.CampAmounts[detail.CampName] = detail.Amount;
            }
            response.ExpenseData.Add(pivotRow);
        }

        // Sort: BIFURCATION first, then by total descending
        response.ExpenseData = response.ExpenseData
            .OrderByDescending(x => x.Category == "BIFURCATION")
            .ThenByDescending(x => x.Total)
            .ToList();

        // ── Build pivot partner rows (partner × camp) ─────────────────
        var partnerPivotGroups = partnerDetails
            .GroupBy(x => new { x.PartnerId, x.PartnerName })
            .ToList();

        foreach (var grp in partnerPivotGroups)
        {
            var pivotRow = new MISPartnerPivotRow
            {
                PartnerId   = grp.Key.PartnerId,
                PartnerName = grp.Key.PartnerName,
                Total       = grp.Sum(x => x.ShareAmount),
            };
            foreach (var detail in grp)
            {
                if (!string.IsNullOrEmpty(detail.CampName))
                    pivotRow.CampAmounts[detail.CampName] = detail.ShareAmount;
            }
            response.PartnerData.Add(pivotRow);
        }

        // Sort partners by name
        response.PartnerData = response.PartnerData
            .OrderBy(x => x.PartnerName)
            .ToList();

        return Ok(ApiResponse<MISDashboardResponse>.Ok(
            response,
            "MIS Dashboard data retrieved successfully."));
    }
}
