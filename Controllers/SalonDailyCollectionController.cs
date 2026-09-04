using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonDailyCollectionController : BaseApiController
{
    private readonly ISalonDailyCollectionService _service;
    private readonly IDbConnectionFactory         _factory;

    public SalonDailyCollectionController(
        ISalonDailyCollectionService service,
        IActivityLogService          log,
        IDbConnectionFactory         factory)
    {
        _service     = service;
        _activityLog = log;
        _factory     = factory;
    }

    // ── POST /api/SalonDailyCollection/post-daily ─────────────────────────────
    [HttpPost("post-daily")]
    public async Task<IActionResult> PostDaily([FromBody] SalonDailyPostingRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.PostDailyAsync(request, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Insert, ActivityModule.SalonMaster,
                $"Daily posting: {result.Data!.CollectionsInserted} collections, {result.Data.ExpencesInserted} expenses",
                "", "SalonDailyPosting");
        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── GET /api/SalonDailyCollection/collections ─────────────────────────────
    [HttpGet("collections")]
    public async Task<IActionResult> GetCollections([FromQuery] SDCollectionListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllCollectionsAsync(request));
    }

    // ── GET /api/SalonDailyCollection/collections/{id} ────────────────────────
    [HttpGet("collections/{id:int}")]
    public async Task<IActionResult> GetCollectionById(int id)
    {
        var result = await _service.GetCollectionByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── PUT /api/SalonDailyCollection/collections/{id} ────────────────────────
    [HttpPut("collections/{id:int}")]
    public async Task<IActionResult> UpdateCollection(int id, [FromBody] UpdateSDCollectionRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateCollectionAsync(id, request, CurrentUserId);
        if (result.Success)
            await Log(ActivityType.Update, ActivityModule.SalonMaster,
                $"Updated SDCollection #{id}", id.ToString(), "SDCollection");
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── DELETE /api/SalonDailyCollection/collections/{id} ────────────────────
    [HttpDelete("collections/{id:int}")]
    public async Task<IActionResult> DeleteCollection(int id)
    {
        var result = await _service.DeleteCollectionAsync(id, CurrentUserId);
        if (result.Success)
            await Log(ActivityType.Delete, ActivityModule.SalonMaster,
                $"Deleted SDCollection #{id}", id.ToString(), "SDCollection");
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── DELETE /api/SalonDailyCollection/by-date
    // Deletes ALL SDCollection + SDExpence records for given Date + SalonId
    // Query params: date (YYYY-MM-DD), salonId
    [HttpDelete("by-date")]
    public async Task<IActionResult> DeleteByDate(
        [FromQuery] string date,
        [FromQuery] int    salonId)
    {
        if (string.IsNullOrEmpty(date) || salonId <= 0)
            return BadRequest(new { success = false, message = "date and salonId are required." });

        if (!DateTime.TryParse(date, out var parsedDate))
            return BadRequest(new { success = false, message = "Invalid date format. Use YYYY-MM-DD." });

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteSDCollectionByDate", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Date",      parsedDate.Date);
        cmd.Parameters.AddWithValue("@SalonId",   salonId);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)CurrentUserName ?? DBNull.Value);

        int collectionDeleted = 0, expenceDeleted = 0;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            collectionDeleted = reader.IsDBNull(0) ? 0 : reader.GetInt32(0);
            expenceDeleted    = reader.IsDBNull(1) ? 0 : reader.GetInt32(1);
        }
        await reader.CloseAsync();

        await Log(ActivityType.Delete, ActivityModule.SalonMaster,
            $"Deleted by date {date} SalonId {salonId}: {collectionDeleted} collections, {expenceDeleted} expenses",
            date, "SDCollectionByDate");

        return Ok(new
        {
            success = true,
            message = $"Deleted {collectionDeleted} collection(s) and {expenceDeleted} expense(s) for {date}.",
            data    = new { collectionDeleted, expenceDeleted, date, salonId }
        });
    }

    // ── GET /api/SalonDailyCollection/pivot ───────────────────────────────────
    // Pivot format: date as row, staff names as columns
    // All params optional: SalonId, StaffId, DateFrom, DateTo, SearchText, PageNumber, PageSize
    [HttpGet("pivot")]
    public async Task<IActionResult> GetPivot([FromQuery] SDCollectionPivotRequest request)
    {
        int pageNumber = request.PageNumber > 0 ? request.PageNumber : 1;
        int pageSize   = request.PageSize   > 0 ? request.PageSize   : 10;

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSDCollectionPivot", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@SalonId",    (object?)request.SalonId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@StaffId",    (object?)request.StaffId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo)   ? DBNull.Value : (object)DateTime.Parse(request.DateTo));
        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", pageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   pageSize);

        var totalDatesParam = new SqlParameter("@TotalDates", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalDatesParam);

        await using var reader = await cmd.ExecuteReaderAsync(CommandBehavior.Default);

        // Result 1: paged raw collection rows
        var rawRows = new List<(string Date, int CollectionId, int StaffId, string StaffName, decimal Amount)>();
        while (await reader.ReadAsync())
        {
            rawRows.Add((
                reader.GetDateTime(reader.GetOrdinal("Date")).ToString("dd/MM/yyyy"),
                reader.GetInt32(reader.GetOrdinal("CollectionId")),
                reader.GetInt32(reader.GetOrdinal("StaffId")),
                reader.GetString(reader.GetOrdinal("StaffName")),
                reader.GetDecimal(reader.GetOrdinal("Amount"))
            ));
        }

        // Result 2: expenses for paged dates
        await reader.NextResultAsync();
        var expenseByDate = new Dictionary<string, (decimal DC, decimal CO, decimal Total)>();
        while (await reader.ReadAsync())
        {
            var date  = reader.GetDateTime(reader.GetOrdinal("Date")).ToString("dd/MM/yyyy");
            var dc    = reader.IsDBNull(reader.GetOrdinal("DCExpense"))    ? 0 : reader.GetDecimal(reader.GetOrdinal("DCExpense"));
            var co    = reader.IsDBNull(reader.GetOrdinal("COExpense"))    ? 0 : reader.GetDecimal(reader.GetOrdinal("COExpense"));
            var total = reader.IsDBNull(reader.GetOrdinal("TotalExpense")) ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalExpense"));
            expenseByDate[date] = (dc, co, total);
        }

        // Result 3: distinct staff list
        await reader.NextResultAsync();
        var staffList = new List<(int Id, string Name)>();
        while (await reader.ReadAsync())
            staffList.Add((reader.GetInt32(0), reader.GetString(1)));

        // Result 4: grand totals
        await reader.NextResultAsync();
        decimal grandDC = 0, grandCO = 0, grandExpense = 0;
        if (await reader.ReadAsync())
        {
            grandDC      = reader.IsDBNull(1) ? 0 : reader.GetDecimal(1);
            grandCO      = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2);
            grandExpense = reader.IsDBNull(3) ? 0 : reader.GetDecimal(3);
        }

        // Result 5: TotalDates for pagination
        await reader.NextResultAsync();
        int totalDatesFromResultSet = 0;
        if (await reader.ReadAsync())
            totalDatesFromResultSet = reader.IsDBNull(0) ? 0 : reader.GetInt32(0);

        await reader.CloseAsync();

        // ── Read output param AFTER reader is closed ──────────────────────
        int totalDates = totalDatesParam.Value == DBNull.Value ? 0 : (int)totalDatesParam.Value;
        // Use result set value as fallback if output param is 0
        if (totalDates == 0) totalDates = totalDatesFromResultSet;
        int totalPages = (int)Math.Ceiling((double)totalDates / pageSize);

        // Build pivot
        var pivotByDate = new Dictionary<string, SDCollectionPivotRow>();
        foreach (var (date, collectionId, _, staffName, amount) in rawRows)
        {
            if (!pivotByDate.TryGetValue(date, out var row))
            {
                row = new SDCollectionPivotRow { Date = date };
                if (expenseByDate.TryGetValue(date, out var exp))
                {
                    row.DCExpense    = exp.DC;
                    row.COExpense    = exp.CO;
                    row.TotalExpense = exp.Total;
                }
                pivotByDate[date] = row;
            }
            row.StaffAmounts[staffName]  = amount;
            row.CollectionIds[staffName] = collectionId;   // ← for delete/detail
        }

        // Fill 0 for missing staff on each date
        foreach (var row in pivotByDate.Values)
            foreach (var (_, name) in staffList)
                if (!row.StaffAmounts.ContainsKey(name))
                    row.StaffAmounts[name] = 0;

        var rows = pivotByDate.Values.OrderBy(r => r.Date).ToList();

        // Grand totals row
        var totals = new SDCollectionPivotRow { Date = "Total" };
        foreach (var (_, name) in staffList)
            totals.StaffAmounts[name] = rows.Sum(r => r.StaffAmounts.GetValueOrDefault(name, 0));
        totals.DCExpense    = grandDC;
        totals.COExpense    = grandCO;
        totals.TotalExpense = grandExpense;

        var result = new SDCollectionPivotResponse
        {
            StaffColumns = staffList.Select(s => s.Name).ToList(),
            Rows         = rows,
            Totals       = totals,
            TotalRecords = totalDates,
            PageNumber   = pageNumber,
            PageSize     = pageSize,
            TotalPages   = totalPages
        };

        return Ok(new { success = true, message = "Collection pivot retrieved.", data = result });
    }
}
