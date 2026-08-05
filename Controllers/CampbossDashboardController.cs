using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CampbossDashboardController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;
    public CampbossDashboardController(IDbConnectionFactory factory, IActivityLogService log)
    { _factory = factory; _activityLog = log; }

    /// <summary>
    /// GET /api/CampbossDashboard/{campbossId}
    /// Dashboard: cards + assigned camps + recent transactions (expenses)
    /// </summary>
    [HttpGet("{campbossId:int}")]
    public async Task<IActionResult> GetDashboard(int campbossId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // ── 1. Get assigned camp IDs ──────────────────────────
        var campIds = new List<int>();
        await using (var cmd = new SqlCommand(
            "SELECT CampId FROM CampCampbosses WHERE CampbossId=@CampbossId AND ISNULL(IsDeleted,0)=0", conn))
        {
            cmd.Parameters.AddWithValue("@CampbossId", campbossId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync()) campIds.Add(r.GetInt32(0));
        }

        if (campIds.Count == 0)
        {
            return Ok(ApiResponse<object>.Ok(new
            {
                totalAssignedCamps = 0,
                totalRooms         = 0,
                vacantRooms        = 0,
                occupiedRooms      = 0,
                assignedCamps      = new List<object>(),
                recentTransactions = new List<object>()
            }, "Campboss dashboard retrieved."));
        }

        var campIdsStr = string.Join(",", campIds);

        // ── 2. Cards — Room stats across assigned camps ───────
        int totalRooms = 0, vacantRooms = 0, occupiedRooms = 0;
        await using (var cmd = new SqlCommand(
            $@"SELECT
                COUNT(*)                                              AS TotalRooms,
                SUM(CASE WHEN Status='Vacant'   THEN 1 ELSE 0 END)   AS VacantRooms,
                SUM(CASE WHEN Status='Occupied' THEN 1 ELSE 0 END)   AS OccupiedRooms
            FROM Rooms WHERE CampId IN ({campIdsStr}) AND IsDeleted=0", conn))
        {
            await using var r = await cmd.ExecuteReaderAsync();
            if (await r.ReadAsync())
            {
                totalRooms    = r.IsDBNull(0) ? 0 : r.GetInt32(0);
                vacantRooms   = r.IsDBNull(1) ? 0 : r.GetInt32(1);
                occupiedRooms = r.IsDBNull(2) ? 0 : r.GetInt32(2);
            }
        }

        // ── 3. Assigned Camps list ────────────────────────────
        var assignedCamps = new List<object>();
        await using (var cmd = new SqlCommand(
            $@"SELECT c.Id, c.Code, c.Name, c.Rooms, c.Floors, c.Status,
                cc.Type, cc.Amount
            FROM CampCampbosses cc
            JOIN Camps c ON c.Id=cc.CampId AND c.IsDeleted=0
            WHERE cc.CampbossId=@CampbossId AND ISNULL(cc.IsDeleted,0)=0
            ORDER BY c.Name", conn))
        {
            cmd.Parameters.AddWithValue("@CampbossId", campbossId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                assignedCamps.Add(new
                {
                    campId   = r.GetInt32(r.GetOrdinal("Id")),
                    campCode = r.IsDBNull(r.GetOrdinal("Code"))   ? "" : r.GetString(r.GetOrdinal("Code")),
                    campName = r.IsDBNull(r.GetOrdinal("Name"))   ? "" : r.GetString(r.GetOrdinal("Name")),
                    rooms    = r.GetInt32(r.GetOrdinal("Rooms")),
                    floors   = r.GetInt32(r.GetOrdinal("Floors")),
                    status   = r.IsDBNull(r.GetOrdinal("Status")) ? "" : r.GetString(r.GetOrdinal("Status")),
                    type     = r.IsDBNull(r.GetOrdinal("Type"))   ? "" : r.GetString(r.GetOrdinal("Type")),
                    amount   = r.IsDBNull(r.GetOrdinal("Amount")) ? 0m : r.GetDecimal(r.GetOrdinal("Amount")),
                });
            }
        }

        // ── 4. Recent Transactions (Expenses where CampId in assigned camps) ─
        var recentTransactions = new List<object>();
        await using (var cmd = new SqlCommand(
            $@"SELECT TOP 20
                e.Id, e.ExpenseId, e.Date, e.Mode, e.Head, e.FundPool,
                e.Amount, e.Nature, e.CampId,
                ISNULL(c.Name,'') AS CampName,
                e.RecipientRole, e.RecipientName, e.Purpose,
                e.CreatedAt
            FROM Expenses e
            LEFT JOIN Camps c ON c.Id=e.CampId
            WHERE e.IsDeleted=0 AND e.CampId IN ({campIdsStr})
            ORDER BY e.Date DESC, e.Id DESC", conn))
        {
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                recentTransactions.Add(new
                {
                    id            = r.GetInt32(r.GetOrdinal("Id")),
                    expenseId     = r.IsDBNull(r.GetOrdinal("ExpenseId"))     ? "" : r.GetString(r.GetOrdinal("ExpenseId")),
                    date          = r.GetDateTime(r.GetOrdinal("Date")).ToString("yyyy-MM-dd"),
                    mode          = r.IsDBNull(r.GetOrdinal("Mode"))          ? "" : r.GetString(r.GetOrdinal("Mode")),
                    head          = r.IsDBNull(r.GetOrdinal("Head"))          ? "" : r.GetString(r.GetOrdinal("Head")),
                    fundPool      = r.IsDBNull(r.GetOrdinal("FundPool"))      ? "" : r.GetString(r.GetOrdinal("FundPool")),
                    amount        = r.GetDecimal(r.GetOrdinal("Amount")),
                    nature        = r.IsDBNull(r.GetOrdinal("Nature"))        ? "" : r.GetString(r.GetOrdinal("Nature")),
                    campId        = r.IsDBNull(r.GetOrdinal("CampId"))        ? 0  : r.GetInt32(r.GetOrdinal("CampId")),
                    campName      = r.IsDBNull(r.GetOrdinal("CampName"))      ? "" : r.GetString(r.GetOrdinal("CampName")),
                    recipientRole = r.IsDBNull(r.GetOrdinal("RecipientRole")) ? "" : r.GetString(r.GetOrdinal("RecipientRole")),
                    recipientName = r.IsDBNull(r.GetOrdinal("RecipientName")) ? "" : r.GetString(r.GetOrdinal("RecipientName")),
                    purpose       = r.IsDBNull(r.GetOrdinal("Purpose"))       ? "" : r.GetString(r.GetOrdinal("Purpose")),
                    createdAt     = r.GetDateTime(r.GetOrdinal("CreatedAt")),
                });
            }
        }

        return Ok(ApiResponse<object>.Ok(new
        {
            totalAssignedCamps = campIds.Count,
            totalRooms,
            vacantRooms,
            occupiedRooms,
            assignedCamps,
            recentTransactions
        }, "Campboss dashboard retrieved."));
    }
}
