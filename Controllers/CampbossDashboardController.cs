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
                campCollections    = new List<object>(),
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
                cc.Type, cc.Amount,
                ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0), 0) AS TotalRooms,
                ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Vacant'), 0) AS VacantRooms,
                ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Occupied'), 0) AS OccupiedRooms
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
                    campId        = r.GetInt32(r.GetOrdinal("Id")),
                    campCode      = r.IsDBNull(r.GetOrdinal("Code"))   ? "" : r.GetString(r.GetOrdinal("Code")),
                    campName      = r.IsDBNull(r.GetOrdinal("Name"))   ? "" : r.GetString(r.GetOrdinal("Name")),
                    rooms         = r.GetInt32(r.GetOrdinal("Rooms")),
                    floors        = r.GetInt32(r.GetOrdinal("Floors")),
                    status        = r.IsDBNull(r.GetOrdinal("Status")) ? "" : r.GetString(r.GetOrdinal("Status")),
                    type          = r.IsDBNull(r.GetOrdinal("Type"))   ? "" : r.GetString(r.GetOrdinal("Type")),
                    amount        = r.IsDBNull(r.GetOrdinal("Amount")) ? 0m : r.GetDecimal(r.GetOrdinal("Amount")),
                    totalRooms    = r.GetInt32(r.GetOrdinal("TotalRooms")),
                    vacantRooms   = r.GetInt32(r.GetOrdinal("VacantRooms")),
                    occupiedRooms = r.GetInt32(r.GetOrdinal("OccupiedRooms")),
                });
            }
        }

        // ── 4. Camp-wise Collection from ContractRoomInstallments ──────────────
        var campCollections = new List<object>();
        await using (var cmd = new SqlCommand(
            $@"SELECT
                cri.CampId,
                ISNULL(c.Name,'')                                        AS CampName,
                ISNULL(c.Code,'')                                        AS CampCode,
                COUNT(DISTINCT cri.ContractId)                           AS TotalContracts,
                COUNT(DISTINCT cri.RoomId)                               AS TotalRooms,
                ISNULL(SUM(cri.InstallAmount), 0)                        AS TotalAmount,

                -- CollectedAmount: Paid + PaidPartial
                ISNULL(SUM(CASE WHEN cri.Status IN ('Paid','PaidPartial')
                                THEN cri.PaidAmount ELSE 0 END), 0)      AS CollectedAmount,

                -- AdvanceCollection: Advanced + AdvancedPartial
                ISNULL(SUM(CASE WHEN cri.Status IN ('Advanced','AdvancedPartial')
                                THEN cri.PaidAmount ELSE 0 END), 0)      AS AdvanceCollection,

                -- PendingAmount: Pending balance
                ISNULL(SUM(CASE WHEN cri.Status = 'Pending'
                                THEN cri.Balance ELSE 0 END), 0)         AS PendingAmount
            FROM ContractRoomInstallments cri
            LEFT JOIN Camps c ON c.Id = cri.CampId
            WHERE cri.CampId IN ({campIdsStr})
              AND ISNULL(cri.IsDeleted, 0) = 0
            GROUP BY cri.CampId, c.Name, c.Code
            ORDER BY CollectedAmount DESC", conn))
        {
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                var totalAmt     = r.IsDBNull(r.GetOrdinal("TotalAmount"))        ? 0m : r.GetDecimal(r.GetOrdinal("TotalAmount"));
                var collectedAmt = r.IsDBNull(r.GetOrdinal("CollectedAmount"))    ? 0m : r.GetDecimal(r.GetOrdinal("CollectedAmount"));
                campCollections.Add(new
                {
                    campId            = r.GetInt32(r.GetOrdinal("CampId")),
                    campName          = r.GetString(r.GetOrdinal("CampName")),
                    campCode          = r.GetString(r.GetOrdinal("CampCode")),
                    totalContracts    = r.GetInt32(r.GetOrdinal("TotalContracts")),
                    totalRooms        = r.GetInt32(r.GetOrdinal("TotalRooms")),
                    totalAmount       = totalAmt,
                    collectedAmount   = collectedAmt,
                    advanceCollection = r.IsDBNull(r.GetOrdinal("AdvanceCollection"))? 0m : r.GetDecimal(r.GetOrdinal("AdvanceCollection")),
                    pendingAmount     = r.IsDBNull(r.GetOrdinal("PendingAmount"))    ? 0m : r.GetDecimal(r.GetOrdinal("PendingAmount")),
                    collectionPct     = totalAmt > 0 ? Math.Round(collectedAmt / totalAmt * 100, 1) : 0m,
                });
            }
        }

        // ── 5. Recent Transactions (Expenses + Incomes for assigned camps) ────
        var recentTransactions = new List<object>();
        await using (var cmd = new SqlCommand(
            $@"SELECT TOP 20
                txn.TxnType, txn.Id, txn.TxnRefId, txn.Date, txn.Mode,
                txn.Head, txn.FundPool, txn.Amount, txn.Nature,
                txn.CampId, txn.CampName, txn.RecipientRole,
                txn.RecipientName, txn.Purpose, txn.CreatedAt
            FROM (
                -- Expenses
                SELECT
                    'Expense'             AS TxnType,
                    e.Id,
                    e.ExpenseId           AS TxnRefId,
                    e.Date,
                    ISNULL(e.Mode,'')     AS Mode,
                    ISNULL(e.Head,'')     AS Head,
                    ISNULL(e.FundPool,'') AS FundPool,
                    e.Amount,
                    ISNULL(e.Nature,'')   AS Nature,
                    ISNULL(e.CampId,0)    AS CampId,
                    ISNULL(c1.Name,'')    AS CampName,
                    ISNULL(e.RecipientRole,'')  AS RecipientRole,
                    ISNULL(e.RecipientName,'')  AS RecipientName,
                    ISNULL(e.Purpose,'')        AS Purpose,
                    e.CreatedAt
                FROM Expenses e
                LEFT JOIN Camps c1 ON c1.Id = e.CampId
                WHERE e.IsDeleted = 0
                  AND e.CampId IN ({campIdsStr})

                UNION ALL

                -- Incomes
                SELECT
                    'Income'              AS TxnType,
                    i.Id,
                    i.IncomeId            AS TxnRefId,
                    i.Date,
                    ISNULL(i.Mode,'')     AS Mode,
                    ISNULL(i.Head,'')     AS Head,
                    ISNULL(i.FundPool,'') AS FundPool,
                    i.Amount,
                    ''                    AS Nature,
                    ISNULL(i.CampId,0)    AS CampId,
                    ISNULL(c2.Name,'')    AS CampName,
                    ISNULL(i.Source,'')   AS RecipientRole,
                    ISNULL(i.TenantName, ISNULL(i.PartnerName,'')) AS RecipientName,
                    ISNULL(i.Purpose,'')  AS Purpose,
                    i.CreatedAt
                FROM Incomes i
                LEFT JOIN Camps c2 ON c2.Id = i.CampId
                WHERE i.IsDeleted = 0
                  AND i.CampId IN ({campIdsStr})
            ) txn
            ORDER BY txn.Date DESC, txn.Id DESC", conn))
        {
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                recentTransactions.Add(new
                {
                    txnType       = r.IsDBNull(r.GetOrdinal("TxnType"))       ? "" : r.GetString(r.GetOrdinal("TxnType")),
                    id            = r.GetInt32(r.GetOrdinal("Id")),
                    txnRefId      = r.IsDBNull(r.GetOrdinal("TxnRefId"))      ? "" : r.GetString(r.GetOrdinal("TxnRefId")),
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
            campCollections,
            recentTransactions
        }, "Campboss dashboard retrieved."));
    }
}
