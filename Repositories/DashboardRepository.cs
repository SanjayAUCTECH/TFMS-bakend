using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class DashboardRepository : IDashboardRepository
{
    private readonly IDbConnectionFactory _factory;
    public DashboardRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<DashboardStatsResponse> GetStatsAsync(int? campId = null, int? tenantId = null, string? month = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var stats = new DashboardStatsResponse();

        // Parse month filter
        int? filterYear = null, filterMonth = null;
        if (!string.IsNullOrEmpty(month) && month.Length == 7)
        {
            var parts = month.Split('-');
            if (parts.Length == 2 && int.TryParse(parts[0], out var y) && int.TryParse(parts[1], out var m))
            { filterYear = y; filterMonth = m; }
        }

        // ── 1. KPI stats from SP (filtered by campId, tenantId, month) ──────
        await using (var cmd = new SqlCommand("sp_GetDashboardStats", conn) { CommandType = CommandType.StoredProcedure })
        {
            cmd.Parameters.AddWithValue("@CampId",   (object?)campId   ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@TenantId", (object?)tenantId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@Year",     (object?)filterYear  ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@Month",    (object?)filterMonth ?? DBNull.Value);
            await using var r = await cmd.ExecuteReaderAsync();
            if (await r.ReadAsync())
            {
                stats.TotalCamps              = r.IsDBNull(r.GetOrdinal("TotalCamps"))              ? 0 : r.GetInt32(r.GetOrdinal("TotalCamps"));
                stats.TotalRooms              = r.IsDBNull(r.GetOrdinal("TotalRooms"))              ? 0 : r.GetInt32(r.GetOrdinal("TotalRooms"));
                stats.OccupiedRooms           = r.IsDBNull(r.GetOrdinal("OccupiedRooms"))           ? 0 : r.GetInt32(r.GetOrdinal("OccupiedRooms"));
                stats.VacantRooms             = r.IsDBNull(r.GetOrdinal("VacantRooms"))             ? 0 : r.GetInt32(r.GetOrdinal("VacantRooms"));
                stats.TotalTenants            = r.IsDBNull(r.GetOrdinal("TotalTenants"))            ? 0 : r.GetInt32(r.GetOrdinal("TotalTenants"));
                stats.ActiveTenants           = r.IsDBNull(r.GetOrdinal("ActiveTenants"))           ? 0 : r.GetInt32(r.GetOrdinal("ActiveTenants"));
                stats.TotalPartners           = r.IsDBNull(r.GetOrdinal("TotalPartners"))           ? 0 : r.GetInt32(r.GetOrdinal("TotalPartners"));
                stats.ActiveContracts         = r.IsDBNull(r.GetOrdinal("ActiveContracts"))         ? 0 : r.GetInt32(r.GetOrdinal("ActiveContracts"));
                stats.TotalDueThisMonth       = r.IsDBNull(r.GetOrdinal("TotalDueThisMonth"))       ? 0 : r.GetDecimal(r.GetOrdinal("TotalDueThisMonth"));
                stats.TotalCollectedThisMonth = r.IsDBNull(r.GetOrdinal("TotalCollectedThisMonth")) ? 0 : r.GetDecimal(r.GetOrdinal("TotalCollectedThisMonth"));
                stats.OutstandingBalance      = r.IsDBNull(r.GetOrdinal("OutstandingBalance"))      ? 0 : r.GetDecimal(r.GetOrdinal("OutstandingBalance"));
                stats.OverduePayments         = r.IsDBNull(r.GetOrdinal("OverduePayments"))         ? 0 : r.GetInt32(r.GetOrdinal("OverduePayments"));
            }
        }

        // ── 2. Camp Occupancy Chart (filtered by campId) ─────────────────
        var campWhere = campId.HasValue ? "WHERE c.Status='Active' AND c.Id=@CampId" : "WHERE c.Status='Active'";
        await using (var cmd2 = new SqlCommand($@"
            SELECT c.Name CampName,
                COUNT(r.Id) TotalRooms,
                SUM(CASE WHEN r.Status='Occupied' THEN 1 ELSE 0 END) Occupied,
                SUM(CASE WHEN r.Status='Vacant'   THEN 1 ELSE 0 END) Vacant
            FROM Camps c LEFT JOIN Rooms r ON r.CampId=c.Id
            {campWhere}
            GROUP BY c.Id, c.Name ORDER BY c.Name", conn))
        {
            if (campId.HasValue) cmd2.Parameters.AddWithValue("@CampId", campId.Value);
            await using var r2 = await cmd2.ExecuteReaderAsync();
            while (await r2.ReadAsync())
                stats.CampOccupancy.Add(new DashCampOccupancy {
                    CampName   = r2.GetString(0),
                    TotalRooms = r2.IsDBNull(1) ? 0 : r2.GetInt32(1),
                    Occupied   = r2.IsDBNull(2) ? 0 : r2.GetInt32(2),
                    Vacant     = r2.IsDBNull(3) ? 0 : r2.GetInt32(3),
                });
        }

        // ── 3. Monthly Collections Chart (filtered by campId, tenantId, month/year) ──
        var collYear  = filterYear  ?? DateTime.UtcNow.Year;
        var collWhere = new List<string> { "ci.Status='Paid'", "YEAR(ci.PaidDate)=@Year" };
        if (campId.HasValue)   collWhere.Add("ct.Id IN (SELECT ContractId FROM ContractCamps WHERE CampId=@CampId)");
        if (tenantId.HasValue) collWhere.Add("ct.TenantId=@TenantId");
        var collSql = $@"
            SELECT MONTH(ci.PaidDate) MonthNum, SUM(ci.PaidAmount) Collected
            FROM ContractInstallments ci
            JOIN Contracts ct ON ct.ContractId=ci.ContractId
            WHERE {string.Join(" AND ", collWhere)}
            GROUP BY MONTH(ci.PaidDate) ORDER BY MONTH(ci.PaidDate)";
        await using (var cmd3 = new SqlCommand(collSql, conn))
        {
            cmd3.Parameters.AddWithValue("@Year", collYear);
            if (campId.HasValue)   cmd3.Parameters.AddWithValue("@CampId",   campId.Value);
            if (tenantId.HasValue) cmd3.Parameters.AddWithValue("@TenantId", tenantId.Value);
            var monthMap = new Dictionary<int, decimal>();
            await using (var r3 = await cmd3.ExecuteReaderAsync())
                while (await r3.ReadAsync())
                    monthMap[r3.GetInt32(0)] = r3.IsDBNull(1) ? 0 : r3.GetDecimal(1);
            var monthNames = new[] {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
            for (int i = 1; i <= 12; i++)
                stats.MonthlyCollections.Add(new DashMonthlyCollection {
                    Month     = monthNames[i - 1],
                    Collected = monthMap.TryGetValue(i, out var v) ? v : 0,
                });
        }

        // ── 4. Revenue by Camp Chart (filtered by campId) ─────────────────
        var revWhere = campId.HasValue ? "WHERE c.Status='Active' AND c.Id=@CampId" : "WHERE c.Status='Active'";
        await using (var cmd4 = new SqlCommand($@"
            SELECT c.Name CampName, ISNULL(SUM(r.MonthlyPrice),0) MonthlyRevenue
            FROM Camps c LEFT JOIN Rooms r ON r.CampId=c.Id AND r.Status='Occupied'
            {revWhere}
            GROUP BY c.Id, c.Name ORDER BY c.Name", conn))
        {
            if (campId.HasValue) cmd4.Parameters.AddWithValue("@CampId", campId.Value);
            await using var r4 = await cmd4.ExecuteReaderAsync();
            while (await r4.ReadAsync())
                stats.CampRevenue.Add(new DashCampRevenue {
                    CampName       = r4.GetString(0),
                    MonthlyRevenue = r4.IsDBNull(1) ? 0 : r4.GetDecimal(1),
                });
        }

        // ── 5. Payment Doughnut (filtered by campId, tenantId, month) ────
        var payWhere = new List<string>();
        if (campId.HasValue)   payWhere.Add("ci2.ContractId IN (SELECT ContractId FROM ContractCamps WHERE CampId=@CampId)");
        if (tenantId.HasValue) payWhere.Add("ct2.TenantId=@TenantId");
        if (filterMonth.HasValue) payWhere.Add("MONTH(ci2.PaidDate)=@Month AND YEAR(ci2.PaidDate)=@Year2");
        var payJoin   = tenantId.HasValue ? "JOIN Contracts ct2 ON ct2.ContractId=ci2.ContractId" : "";
        var payFilter = payWhere.Count > 0 ? "WHERE " + string.Join(" AND ", payWhere) : "";
        await using (var cmd5 = new SqlCommand($@"
            SELECT
                ISNULL(SUM(CASE WHEN ci2.Status='Paid'    THEN ci2.PaidAmount ELSE 0 END),0) TotalPaid,
                ISNULL(SUM(CASE WHEN ci2.Status='Pending' THEN ci2.Amount     ELSE 0 END),0) TotalPending
            FROM ContractInstallments ci2
            {payJoin}
            {payFilter}", conn))
        {
            if (campId.HasValue)   cmd5.Parameters.AddWithValue("@CampId",   campId.Value);
            if (tenantId.HasValue) cmd5.Parameters.AddWithValue("@TenantId", tenantId.Value);
            if (filterMonth.HasValue) { cmd5.Parameters.AddWithValue("@Month", filterMonth.Value); cmd5.Parameters.AddWithValue("@Year2", filterYear!.Value); }
            await using var r5 = await cmd5.ExecuteReaderAsync();
            if (await r5.ReadAsync())
            {
                stats.TotalPaidAmount    = r5.IsDBNull(0) ? 0 : r5.GetDecimal(0);
                stats.TotalPendingAmount = r5.IsDBNull(1) ? 0 : r5.GetDecimal(1);
            }
        }

        // ── 6. Contract Status Pie (filtered by campId, tenantId) ─────────
        var ctWhere = new List<string>();
        if (campId.HasValue)   ctWhere.Add("Id IN (SELECT ContractId FROM ContractCamps WHERE CampId=@CampId)");
        if (tenantId.HasValue) ctWhere.Add("TenantId=@TenantId");
        var ctFilter = ctWhere.Count > 0 ? "WHERE " + string.Join(" AND ", ctWhere) : "";
        await using (var cmd6 = new SqlCommand($@"
            SELECT
                SUM(CASE WHEN Status='Active'    THEN 1 ELSE 0 END) Active,
                SUM(CASE WHEN Status='Completed' THEN 1 ELSE 0 END) Completed
            FROM Contracts {ctFilter}", conn))
        {
            if (campId.HasValue)   cmd6.Parameters.AddWithValue("@CampId",   campId.Value);
            if (tenantId.HasValue) cmd6.Parameters.AddWithValue("@TenantId", tenantId.Value);
            await using var r6 = await cmd6.ExecuteReaderAsync();
            if (await r6.ReadAsync())
            {
                stats.ActiveContracts    = r6.IsDBNull(0) ? 0 : r6.GetInt32(0);
                stats.CompletedContracts = r6.IsDBNull(1) ? 0 : r6.GetInt32(1);
            }
        }

        return stats;
    }

    public async Task<AppUser?> GetUserByUsernameAsync(string username)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM AppUsers WHERE Username=@Username AND LoginAccess='enabled' AND Status='Active'", conn);
        cmd.Parameters.AddWithValue("@Username", username);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;
        return new AppUser
        {
            Id           = r.GetInt32(r.GetOrdinal("Id")),
            UserId       = r.GetString(r.GetOrdinal("UserId")),
            Name         = r.GetString(r.GetOrdinal("Name")),
            Username     = r.GetString(r.GetOrdinal("Username")),
            Password     = r.GetString(r.GetOrdinal("PasswordHash")),
            Role         = r.IsDBNull(r.GetOrdinal("Role"))       ? "" : r.GetString(r.GetOrdinal("Role")),
            Source       = r.IsDBNull(r.GetOrdinal("Source"))     ? "" : r.GetString(r.GetOrdinal("Source")),
            SourceId     = r.IsDBNull(r.GetOrdinal("SourceId"))   ? null : r.GetInt32(r.GetOrdinal("SourceId")),
            Contact      = r.IsDBNull(r.GetOrdinal("Contact"))    ? "" : r.GetString(r.GetOrdinal("Contact")),
            Email        = r.IsDBNull(r.GetOrdinal("Email"))      ? "" : r.GetString(r.GetOrdinal("Email")),
            LastLogin    = r.IsDBNull(r.GetOrdinal("LastLogin"))  ? null : r.GetDateTime(r.GetOrdinal("LastLogin")),
            IsAdmin      = r.GetBoolean(r.GetOrdinal("IsAdmin")),
            MenuAccess   = r.IsDBNull(r.GetOrdinal("MenuAccess")) ? "{}" : r.GetString(r.GetOrdinal("MenuAccess")),
            Status       = r.GetString(r.GetOrdinal("Status")),
            LoginAccess  = r.GetString(r.GetOrdinal("LoginAccess")),
        };
    }

    public async Task UpdateLastLoginAsync(int userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("UPDATE AppUsers SET LastLogin=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", userId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<StaffExpiryAlertResponse> GetStaffExpiryAlertsAsync(int daysAhead = 30)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var result = new StaffExpiryAlertResponse();
        var rows   = new List<StaffExpiryAlertRow>();

        await using var cmd = new SqlCommand("sp_GetStaffExpiryAlerts", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@DaysAhead", daysAhead);

        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var row = new StaffExpiryAlertRow
            {
                StaffId       = r.GetInt32(r.GetOrdinal("StaffId")),
                StaffCode     = r.IsDBNull(r.GetOrdinal("StaffCode"))    ? "" : r.GetString(r.GetOrdinal("StaffCode")),
                StaffName     = r.IsDBNull(r.GetOrdinal("StaffName"))    ? "" : r.GetString(r.GetOrdinal("StaffName")),
                Contact       = r.IsDBNull(r.GetOrdinal("Contact"))      ? "" : r.GetString(r.GetOrdinal("Contact")),
                Designation   = r.IsDBNull(r.GetOrdinal("Designation"))  ? "" : r.GetString(r.GetOrdinal("Designation")),
                DocumentType  = r.IsDBNull(r.GetOrdinal("DocumentType")) ? "" : r.GetString(r.GetOrdinal("DocumentType")),
                ExpiryDate    = r.IsDBNull(r.GetOrdinal("ExpiryDate"))
                                    ? ""
                                    : r.GetDateTime(r.GetOrdinal("ExpiryDate")).ToString("yyyy-MM-dd"),
                DaysRemaining = r.IsDBNull(r.GetOrdinal("DaysRemaining")) ? 0 : r.GetInt32(r.GetOrdinal("DaysRemaining")),
                AlertType     = r.IsDBNull(r.GetOrdinal("AlertType"))    ? "" : r.GetString(r.GetOrdinal("AlertType")),
            };
            rows.Add(row);
        }

        result.Alerts       = rows;
        result.TotalAlerts  = rows.Count;
        result.ExpiredCount = rows.Count(x => x.AlertType == "Expired");
        result.ExpiringSoon = rows.Count(x => x.AlertType == "Expiring Soon");

        return result;
    }

    public async Task<OwnerPaymentAlertResponse> GetOwnerPaymentAlertsAsync(int daysAhead = 2)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var rows = new List<OwnerPaymentAlertRow>();

        await using var cmd = new SqlCommand("sp_GetOwnerPaymentAlerts", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@DaysAhead", daysAhead);

        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            rows.Add(new OwnerPaymentAlertRow
            {
                OwnerId         = r.GetInt32(r.GetOrdinal("OwnerId")),
                OwnerCode       = r.IsDBNull(r.GetOrdinal("OwnerCode"))    ? "" : r.GetString(r.GetOrdinal("OwnerCode")),
                OwnerName       = r.IsDBNull(r.GetOrdinal("OwnerName"))    ? "" : r.GetString(r.GetOrdinal("OwnerName")),
                OwnerContact    = r.IsDBNull(r.GetOrdinal("OwnerContact")) ? "" : r.GetString(r.GetOrdinal("OwnerContact")),
                OwnerContractId = r.GetInt32(r.GetOrdinal("OwnerContractId")),
                ContractCode    = r.IsDBNull(r.GetOrdinal("ContractCode")) ? "" : r.GetString(r.GetOrdinal("ContractCode")),
                CampName        = r.IsDBNull(r.GetOrdinal("CampName"))     ? "" : r.GetString(r.GetOrdinal("CampName")),
                InstallmentId   = r.GetInt32(r.GetOrdinal("InstallmentId")),
                InstallmentNo   = r.GetInt32(r.GetOrdinal("InstallmentNo")),
                Amount          = r.IsDBNull(r.GetOrdinal("Amount"))        ? 0 : r.GetDecimal(r.GetOrdinal("Amount")),
                PaidAmount      = r.IsDBNull(r.GetOrdinal("PaidAmount"))    ? 0 : r.GetDecimal(r.GetOrdinal("PaidAmount")),
                BalanceAmount   = r.IsDBNull(r.GetOrdinal("BalanceAmount")) ? 0 : r.GetDecimal(r.GetOrdinal("BalanceAmount")),
                DueDate         = r.IsDBNull(r.GetOrdinal("DueDate"))
                                      ? ""
                                      : r.GetDateTime(r.GetOrdinal("DueDate")).ToString("yyyy-MM-dd"),
                DaysUntilDue    = r.IsDBNull(r.GetOrdinal("DaysUntilDue")) ? 0 : r.GetInt32(r.GetOrdinal("DaysUntilDue")),
            });
        }

        return new OwnerPaymentAlertResponse
        {
            TotalAlerts = rows.Count,
            TotalAmount = rows.Sum(x => x.BalanceAmount),
            Alerts      = rows,
        };
    }

    public async Task<OwnerMonthSummaryResponse> GetOwnerMonthSummaryAsync(string? month = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var result = new OwnerMonthSummaryResponse
        {
            Month = month ?? DateTime.UtcNow.ToString("yyyy-MM")
        };

        await using var cmd = new SqlCommand("sp_GetOwnerMonthSummary", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Month", (object?)month ?? DBNull.Value);

        // Result set 1 — per-owner rows
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            result.Owners.Add(new OwnerMonthSummaryRow
            {
                OwnerId           = r.GetInt32(r.GetOrdinal("OwnerId")),
                OwnerCode         = r.IsDBNull(r.GetOrdinal("OwnerCode"))   ? "" : r.GetString(r.GetOrdinal("OwnerCode")),
                OwnerName         = r.IsDBNull(r.GetOrdinal("OwnerName"))   ? "" : r.GetString(r.GetOrdinal("OwnerName")),
                Contact           = r.IsDBNull(r.GetOrdinal("Contact"))     ? "" : r.GetString(r.GetOrdinal("Contact")),
                TotalInstallments = r.IsDBNull(r.GetOrdinal("TotalInstallments")) ? 0 : r.GetInt32(r.GetOrdinal("TotalInstallments")),
                TotalAmountDue    = r.IsDBNull(r.GetOrdinal("TotalAmountDue"))    ? 0 : r.GetDecimal(r.GetOrdinal("TotalAmountDue")),
                TotalPaid         = r.IsDBNull(r.GetOrdinal("TotalPaid"))         ? 0 : r.GetDecimal(r.GetOrdinal("TotalPaid")),
                TotalPending      = r.IsDBNull(r.GetOrdinal("TotalPending"))      ? 0 : r.GetDecimal(r.GetOrdinal("TotalPending")),
                PaidCount         = r.IsDBNull(r.GetOrdinal("PaidCount"))         ? 0 : r.GetInt32(r.GetOrdinal("PaidCount")),
                PendingCount      = r.IsDBNull(r.GetOrdinal("PendingCount"))      ? 0 : r.GetInt32(r.GetOrdinal("PendingCount")),
                CampNames         = r.IsDBNull(r.GetOrdinal("CampNames"))         ? "" : r.GetString(r.GetOrdinal("CampNames")),
            });
        }

        // Result set 2 — grand totals
        await r.NextResultAsync();
        if (await r.ReadAsync())
        {
            result.GrandTotalDue     = r.IsDBNull(r.GetOrdinal("GrandTotalDue"))     ? 0 : r.GetDecimal(r.GetOrdinal("GrandTotalDue"));
            result.GrandTotalPaid    = r.IsDBNull(r.GetOrdinal("GrandTotalPaid"))    ? 0 : r.GetDecimal(r.GetOrdinal("GrandTotalPaid"));
            result.GrandTotalPending = r.IsDBNull(r.GetOrdinal("GrandTotalPending")) ? 0 : r.GetDecimal(r.GetOrdinal("GrandTotalPending"));
            result.TotalOwners       = r.IsDBNull(r.GetOrdinal("TotalOwners"))       ? 0 : r.GetInt32(r.GetOrdinal("TotalOwners"));
            result.TotalInstallments = r.IsDBNull(r.GetOrdinal("TotalInstallments")) ? 0 : r.GetInt32(r.GetOrdinal("TotalInstallments"));
        }

        return result;
    }
}
