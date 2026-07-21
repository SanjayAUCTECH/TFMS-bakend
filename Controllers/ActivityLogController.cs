using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ActivityLogController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public ActivityLogController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>GET api/activitylog?PageNumber=1&PageSize=20&ActivityType=LOGIN&Module=Contracts&UserId=1</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int     pageNumber    = 1,
        [FromQuery] int     pageSize      = 20,
        [FromQuery] string? searchText    = null,
        [FromQuery] string? activityType  = null,
        [FromQuery] string? module        = null,
        [FromQuery] int?    userId        = null,
        [FromQuery] string? userName      = null,
        [FromQuery] string? status        = null,
        [FromQuery] string? dateFrom      = null,
        [FromQuery] string? dateTo        = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetActivityLogs", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PageNumber",   pageNumber);
        cmd.Parameters.AddWithValue("@PageSize",     pageSize);
        cmd.Parameters.AddWithValue("@SearchText",   (object?)searchText   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ActivityType", (object?)activityType ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Module",       (object?)module       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UserId",       (object?)userId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UserName",     (object?)userName     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",       (object?)status       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",     (object?)dateFrom     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",       (object?)dateTo       ?? DBNull.Value);

        var pTotal = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pTotal);

        var rows = new List<object>();
        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            while (await rd.ReadAsync())
            {
                rows.Add(new
                {
                    id           = rd.GetInt32(rd.GetOrdinal("Id")),
                    logId        = rd.GetString(rd.GetOrdinal("LogId")),
                    activityType = rd.GetString(rd.GetOrdinal("ActivityType")),
                    module       = rd.GetString(rd.GetOrdinal("Module")),
                    action       = rd.GetString(rd.GetOrdinal("Action")),
                    entityId     = rd.IsDBNull(rd.GetOrdinal("EntityId"))  ? "" : rd.GetString(rd.GetOrdinal("EntityId")),
                    entityType   = rd.IsDBNull(rd.GetOrdinal("EntityType"))? "" : rd.GetString(rd.GetOrdinal("EntityType")),
                    oldValues    = rd.IsDBNull(rd.GetOrdinal("OldValues")) ? null : rd.GetString(rd.GetOrdinal("OldValues")),
                    newValues    = rd.IsDBNull(rd.GetOrdinal("NewValues")) ? null : rd.GetString(rd.GetOrdinal("NewValues")),
                    userId       = rd.IsDBNull(rd.GetOrdinal("UserId"))    ? (int?)null : rd.GetInt32(rd.GetOrdinal("UserId")),
                    userName     = rd.GetString(rd.GetOrdinal("UserName")),
                    userRole     = rd.GetString(rd.GetOrdinal("UserRole")),
                    ipAddress    = rd.GetString(rd.GetOrdinal("IpAddress")),
                    userAgent    = rd.GetString(rd.GetOrdinal("UserAgent")),
                    status       = rd.GetString(rd.GetOrdinal("Status")),
                    errorMessage = rd.IsDBNull(rd.GetOrdinal("ErrorMessage")) ? null : rd.GetString(rd.GetOrdinal("ErrorMessage")),
                    createdAt    = rd.GetDateTime(rd.GetOrdinal("CreatedAt")),
                });
            }
        }

        int total = pTotal.Value != DBNull.Value ? (int)pTotal.Value : rows.Count;

        return Ok(ApiResponse<object>.Ok(new { rows, totalRecords = total },
            "Activity logs retrieved.",
            PaginationHelper.Build(total, pageNumber, pageSize)));
    }

    /// <summary>GET api/activitylog/{id}</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetActivityLogById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var rd = await cmd.ExecuteReaderAsync();
        if (!await rd.ReadAsync()) return NotFound(ApiResponse<object>.Fail("Log not found."));

        return Ok(ApiResponse<object>.Ok(new
        {
            id           = rd.GetInt32(rd.GetOrdinal("Id")),
            logId        = rd.GetString(rd.GetOrdinal("LogId")),
            activityType = rd.GetString(rd.GetOrdinal("ActivityType")),
            module       = rd.GetString(rd.GetOrdinal("Module")),
            action       = rd.GetString(rd.GetOrdinal("Action")),
            entityId     = rd.IsDBNull(rd.GetOrdinal("EntityId"))   ? "" : rd.GetString(rd.GetOrdinal("EntityId")),
            entityType   = rd.IsDBNull(rd.GetOrdinal("EntityType")) ? "" : rd.GetString(rd.GetOrdinal("EntityType")),
            oldValues    = rd.IsDBNull(rd.GetOrdinal("OldValues"))  ? null : rd.GetString(rd.GetOrdinal("OldValues")),
            newValues    = rd.IsDBNull(rd.GetOrdinal("NewValues"))  ? null : rd.GetString(rd.GetOrdinal("NewValues")),
            userId       = rd.IsDBNull(rd.GetOrdinal("UserId"))     ? (int?)null : rd.GetInt32(rd.GetOrdinal("UserId")),
            userName     = rd.GetString(rd.GetOrdinal("UserName")),
            userRole     = rd.GetString(rd.GetOrdinal("UserRole")),
            ipAddress    = rd.GetString(rd.GetOrdinal("IpAddress")),
            userAgent    = rd.GetString(rd.GetOrdinal("UserAgent")),
            status       = rd.GetString(rd.GetOrdinal("Status")),
            errorMessage = rd.IsDBNull(rd.GetOrdinal("ErrorMessage")) ? null : rd.GetString(rd.GetOrdinal("ErrorMessage")),
            createdAt    = rd.GetDateTime(rd.GetOrdinal("CreatedAt")),
        }, "Activity log retrieved."));
    }

    /// <summary>GET api/activitylog/summary</summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(
        [FromQuery] string? dateFrom = null,
        [FromQuery] string? dateTo   = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetActivitySummary", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@DateFrom", (object?)dateFrom ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",   (object?)dateTo   ?? DBNull.Value);

        await using var rd = await cmd.ExecuteReaderAsync();
        if (!await rd.ReadAsync()) return Ok(ApiResponse<object>.Ok(new {}));

        return Ok(ApiResponse<object>.Ok(new
        {
            totalLogs     = rd.IsDBNull(0) ? 0 : rd.GetInt32(0),
            totalLogins   = rd.IsDBNull(1) ? 0 : rd.GetInt32(1),
            totalInserts  = rd.IsDBNull(2) ? 0 : rd.GetInt32(2),
            totalUpdates  = rd.IsDBNull(3) ? 0 : rd.GetInt32(3),
            totalDeletes  = rd.IsDBNull(4) ? 0 : rd.GetInt32(4),
            totalErrors   = rd.IsDBNull(5) ? 0 : rd.GetInt32(5),
            todayLogs     = rd.IsDBNull(6) ? 0 : rd.GetInt32(6),
            uniqueUsers   = rd.IsDBNull(7) ? 0 : rd.GetInt32(7),
        }, "Activity summary retrieved."));
    }
}
