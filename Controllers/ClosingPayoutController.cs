using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ClosingPayoutController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;

    public ClosingPayoutController(IDbConnectionFactory factory, IActivityLogService log)
    {
        _factory     = factory;
        _activityLog = log;
    }

    // ── GET /api/ClosingPayout
    // Filters (all optional): SalonId, DateFrom (YYYY-MM-DD), DateTo (YYYY-MM-DD)
    // Returns: salon-wise + staff-wise collection, collection%, expense share,
    //          net revenue, staff profit, company revenue + grand totals
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] ClosingPayoutRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetClosingPayout", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@SalonId",
            (object?)request.SalonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value
                : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo) ? DBNull.Value
                : (object)DateTime.Parse(request.DateTo));

        // ── Read flat rows from SP ────────────────────────────────────────────
        var flatRows = new List<(
            int SalonId, string SalonName,
            int StaffId, string StaffName,
            decimal StaffCollection, decimal TotalSalonCollection,
            decimal CollectionPercent, decimal TotalSalonExpense,
            decimal ExpenseShare, decimal NetRevenue,
            decimal StaffProfitPercent, decimal StaffProfit,
            decimal CompanyRevenue
        )>();

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            flatRows.Add((
                SalonId:             reader.GetInt32(reader.GetOrdinal("SalonId")),
                SalonName:           reader.GetString(reader.GetOrdinal("SalonName")),
                StaffId:             reader.GetInt32(reader.GetOrdinal("StaffId")),
                StaffName:           reader.GetString(reader.GetOrdinal("StaffName")),
                StaffCollection:     reader.GetDecimal(reader.GetOrdinal("StaffCollection")),
                TotalSalonCollection:reader.GetDecimal(reader.GetOrdinal("TotalSalonCollection")),
                CollectionPercent:   reader.GetDecimal(reader.GetOrdinal("CollectionPercent")),
                TotalSalonExpense:   reader.GetDecimal(reader.GetOrdinal("TotalSalonExpense")),
                ExpenseShare:        reader.GetDecimal(reader.GetOrdinal("ExpenseShare")),
                NetRevenue:          reader.GetDecimal(reader.GetOrdinal("NetRevenue")),
                StaffProfitPercent:  reader.GetDecimal(reader.GetOrdinal("StaffProfitPercent")),
                StaffProfit:         reader.GetDecimal(reader.GetOrdinal("StaffProfit")),
                CompanyRevenue:      reader.GetDecimal(reader.GetOrdinal("CompanyRevenue"))
            ));
        }

        // ── Group by Salon ────────────────────────────────────────────────────
        var salonGroups = flatRows
            .GroupBy(r => r.SalonId)
            .Select(g =>
            {
                var first = g.First();
                var staffList = g.Select(r => new ClosingPayoutStaffRow
                {
                    StaffId            = r.StaffId,
                    StaffName          = r.StaffName,
                    StaffCollection    = r.StaffCollection,
                    CollectionPercent  = r.CollectionPercent,
                    ExpenseShare       = r.ExpenseShare,
                    NetRevenue         = r.NetRevenue,
                    StaffProfitPercent = r.StaffProfitPercent,
                    StaffProfit        = r.StaffProfit,
                    CompanyRevenue     = r.CompanyRevenue
                }).ToList();

                return new ClosingPayoutSalonRow
                {
                    SalonId              = first.SalonId,
                    SalonName            = first.SalonName,
                    TotalSalonCollection = first.TotalSalonCollection,
                    TotalSalonExpense    = first.TotalSalonExpense,
                    TotalNetRevenue      = Math.Round(staffList.Sum(s => s.NetRevenue), 2),
                    TotalStaffProfit     = Math.Round(staffList.Sum(s => s.StaffProfit), 2),
                    TotalCompanyRevenue  = Math.Round(staffList.Sum(s => s.CompanyRevenue), 2),
                    Staff                = staffList
                };
            })
            .ToList();

        // ── Grand totals ──────────────────────────────────────────────────────
        var result = new ClosingPayoutResponse
        {
            Salons               = salonGroups,
            GrandTotalCollection = Math.Round(salonGroups.Sum(s => s.TotalSalonCollection), 2),
            GrandTotalExpense    = Math.Round(salonGroups.Sum(s => s.TotalSalonExpense), 2),
            GrandNetRevenue      = Math.Round(salonGroups.Sum(s => s.TotalNetRevenue), 2),
            GrandStaffProfit     = Math.Round(salonGroups.Sum(s => s.TotalStaffProfit), 2),
            GrandCompanyRevenue  = Math.Round(salonGroups.Sum(s => s.TotalCompanyRevenue), 2),
            DateFrom             = request.DateFrom,
            DateTo               = request.DateTo,
        };

        return Ok(new { success = true, message = "Closing payout calculated.", data = result });
    }

    // ── POST /api/ClosingPayout/save ──────────────────────────────────────────
    // Saves generated payout rows to ClosingPayout table
    // Body: { "rows": [ { salonId, staffId, staffCollection, ... }, ... ] }
    [HttpPost("save")]
    public async Task<IActionResult> Save([FromBody] SaveClosingPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        // Serialize rows to JSON for SP
        var jsonArray = JsonSerializer.Serialize(request.Rows.Select(r => new
        {
            salonId              = r.SalonId,
            salonName            = r.SalonName,
            staffId              = r.StaffId,
            staffName            = r.StaffName,
            dateFrom             = r.DateFrom,
            dateTo               = r.DateTo,
            staffCollection      = r.StaffCollection,
            totalSalonCollection = r.TotalSalonCollection,
            collectionPercent    = r.CollectionPercent,
            totalSalonExpense    = r.TotalSalonExpense,
            expenseShare         = r.ExpenseShare,
            netRevenue           = r.NetRevenue,
            staffProfitPercent   = r.StaffProfitPercent,
            staffProfit          = r.StaffProfit,
            companyRevenue       = r.CompanyRevenue
        }));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_SaveClosingPayout", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PayoutJson", jsonArray);
        cmd.Parameters.AddWithValue("@AddedBy",    (object?)CurrentUserName ?? DBNull.Value);

        var countParam = new SqlParameter("@InsertedCount", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(countParam);

        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.CloseAsync();

        int inserted = countParam.Value == DBNull.Value ? 0 : (int)countParam.Value;

        await Log(ActivityType.Insert, ActivityModule.SalonMaster,
            $"Saved ClosingPayout: {inserted} row(s)", "", "ClosingPayout");

        return Ok(new
        {
            success = true,
            message = $"Closing payout saved successfully. {inserted} record(s) saved.",
            data    = new SaveClosingPayoutResponse
            {
                InsertedCount = inserted,
                Message       = $"{inserted} record(s) saved."
            }
        });
    }

    // ── GET /api/ClosingPayout/last-payout-date ───────────────────────────────
    // Returns the last saved payout DateTo per salon from ClosingPayout table
    // Optional filter: SalonId (if given → returns only that salon's last date)
    // If no SalonId → returns last payout date for ALL salons
    [HttpGet("last-payout-date")]
    public async Task<IActionResult> GetLastPayoutDate([FromQuery] int? salonId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetLastClosingPayoutDate", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@SalonId", (object?)salonId ?? DBNull.Value);

        var rows = new List<object>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            int ordLastDate     = reader.GetOrdinal("LastPayoutDate");
            int ordFromDate     = reader.GetOrdinal("LastPayoutFromDate");
            int ordSavedOn      = reader.GetOrdinal("SavedOn");

            var lastDateTo   = reader.IsDBNull(ordLastDate) ? (DateTime?)null : reader.GetDateTime(ordLastDate);
            var lastDateFrom = reader.IsDBNull(ordFromDate) ? (DateTime?)null : reader.GetDateTime(ordFromDate);
            var savedOn      = reader.IsDBNull(ordSavedOn)  ? (DateTime?)null : reader.GetDateTime(ordSavedOn);

            rows.Add(new
            {
                salonId         = reader.GetInt32(reader.GetOrdinal("SalonId")),
                salonName       = reader.IsDBNull(reader.GetOrdinal("SalonName")) ? null : reader.GetString(reader.GetOrdinal("SalonName")),
                lastPayoutDate  = lastDateTo?.ToString("yyyy-MM-dd"),
                lastPayoutFrom  = lastDateFrom?.ToString("yyyy-MM-dd"),
                lastPayoutDateDisplay = lastDateTo?.ToString("dd/MM/yyyy"),
                lastPayoutFromDisplay = lastDateFrom?.ToString("dd/MM/yyyy"),
                savedOn         = savedOn?.ToString("yyyy-MM-dd"),
                staffCount      = reader.GetInt32(reader.GetOrdinal("StaffCount"))
            });
        }

        // If single salon requested, return single object; else return array
        if (salonId.HasValue)
        {
            var single = rows.FirstOrDefault();
            return Ok(new { success = true, message = "Last payout date retrieved.", data = single });
        }

        return Ok(new { success = true, message = $"{rows.Count} salon(s) payout info retrieved.", data = rows });
    }

    // ── GET /api/ClosingPayout/dates ─────────────────────────────────────────
    // Returns distinct DateFrom+DateTo combinations saved in ClosingPayout table
    // Use for dropdown — "Which payout period do you want to view?"
    // Optional filter: SalonId
    [HttpGet("dates")]
    public async Task<IActionResult> GetDates([FromQuery] int? salonId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetClosingPayoutDates", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@SalonId", (object?)salonId ?? DBNull.Value);

        var rows = new List<ClosingPayoutDateRow>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            int ordDateFrom = reader.GetOrdinal("DateFrom");
            int ordDateTo   = reader.GetOrdinal("DateTo");
            int ordSavedOn  = reader.GetOrdinal("SavedOn");

            var dateFrom = reader.IsDBNull(ordDateFrom) ? (DateTime?)null : reader.GetDateTime(ordDateFrom);
            var dateTo   = reader.IsDBNull(ordDateTo)   ? (DateTime?)null : reader.GetDateTime(ordDateTo);

            // Build label like "Aug 2026 (01/08 – 31/08)"
            string label = dateFrom.HasValue && dateTo.HasValue
                ? $"{dateFrom.Value:dd/MM/yyyy} – {dateTo.Value:dd/MM/yyyy}"
                : "—";

            rows.Add(new ClosingPayoutDateRow
            {
                DateFrom            = dateFrom,
                DateTo              = dateTo,
                SalonCount          = reader.GetInt32(reader.GetOrdinal("SalonCount")),
                StaffCount          = reader.GetInt32(reader.GetOrdinal("StaffCount")),
                TotalRows           = reader.GetInt32(reader.GetOrdinal("TotalRows")),
                TotalCollection     = reader.GetDecimal(reader.GetOrdinal("TotalCollection")),
                TotalStaffProfit    = reader.GetDecimal(reader.GetOrdinal("TotalStaffProfit")),
                TotalCompanyRevenue = reader.GetDecimal(reader.GetOrdinal("TotalCompanyRevenue")),
                SavedOn             = reader.IsDBNull(ordSavedOn) ? null : reader.GetDateTime(ordSavedOn),
                Label               = label
            });
        }

        return Ok(new
        {
            success = true,
            message = $"{rows.Count} payout date(s) found.",
            data    = rows
        });
    }

    // ── GET /api/ClosingPayout/saved ──────────────────────────────────────────
    // Fetch saved payout records from ClosingPayout table
    // Filters (all optional): SalonId, StaffId, DateFrom, DateTo, SearchText, PageNumber, PageSize
    [HttpGet("saved")]
    public async Task<IActionResult> GetSaved([FromQuery] GetClosingPayoutSavedRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetClosingPayoutSaved", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PageNumber",  request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",    request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SalonId",     (object?)request.SalonId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@StaffId",     (object?)request.StaffId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo)   ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var rows = new List<ClosingPayoutSavedRow>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            int ordDateFrom  = reader.GetOrdinal("DateFrom");
            int ordDateTo    = reader.GetOrdinal("DateTo");
            int ordUpdatedAt = reader.GetOrdinal("UpdatedAt");

            rows.Add(new ClosingPayoutSavedRow
            {
                PayoutId             = reader.GetInt32(reader.GetOrdinal("PayoutId")),
                SalonId              = reader.GetInt32(reader.GetOrdinal("SalonId")),
                SalonName            = reader.IsDBNull(reader.GetOrdinal("SalonName"))  ? null : reader.GetString(reader.GetOrdinal("SalonName")),
                StaffId              = reader.GetInt32(reader.GetOrdinal("StaffId")),
                StaffName            = reader.IsDBNull(reader.GetOrdinal("StaffName"))  ? null : reader.GetString(reader.GetOrdinal("StaffName")),
                DateFrom             = reader.IsDBNull(ordDateFrom)  ? null : reader.GetDateTime(ordDateFrom),
                DateTo               = reader.IsDBNull(ordDateTo)    ? null : reader.GetDateTime(ordDateTo),
                StaffCollection      = reader.GetDecimal(reader.GetOrdinal("StaffCollection")),
                TotalSalonCollection = reader.GetDecimal(reader.GetOrdinal("TotalSalonCollection")),
                CollectionPercent    = reader.GetDecimal(reader.GetOrdinal("CollectionPercent")),
                TotalSalonExpense    = reader.GetDecimal(reader.GetOrdinal("TotalSalonExpense")),
                ExpenseShare         = reader.GetDecimal(reader.GetOrdinal("ExpenseShare")),
                NetRevenue           = reader.GetDecimal(reader.GetOrdinal("NetRevenue")),
                StaffProfitPercent   = reader.GetDecimal(reader.GetOrdinal("StaffProfitPercent")),
                StaffProfit          = reader.GetDecimal(reader.GetOrdinal("StaffProfit")),
                CompanyRevenue       = reader.GetDecimal(reader.GetOrdinal("CompanyRevenue")),
                Status               = reader.IsDBNull(reader.GetOrdinal("Status")) ? null : reader.GetString(reader.GetOrdinal("Status")),
                CreatedAt            = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt            = reader.IsDBNull(ordUpdatedAt) ? null : reader.GetDateTime(ordUpdatedAt),
            });
        }
        await reader.CloseAsync();

        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        int pageNumber = request.ResolvedPageNumber;
        int pageSize   = request.ResolvedPageSize;

        return Ok(new
        {
            success    = true,
            message    = "Saved closing payouts retrieved.",
            data       = rows,
            pagination = new
            {
                totalRecords = total,
                pageNumber,
                pageSize,
                totalPages = (int)Math.Ceiling((double)total / pageSize)
            }
        });
    }
}
