using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class ReportRepository : IReportRepository
{
    private readonly IDbConnectionFactory _factory;
    public ReportRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── Helper: fetch all rows from a stored procedure ──────────────────────
    private static TRow ReadRow<TRow>(SqlDataReader rd, Func<SqlDataReader, TRow> map) => map(rd);

    // ── Inventory Report ─────────────────────────────────────────────────────
    public async Task<InventoryReportResponse> GetInventoryReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetInventoryReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize",   int.MaxValue);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)r.CampId     ?? DBNull.Value);
        cmd.Parameters.Add(new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output });
        var all = new List<InventoryReportRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) all.Add(new InventoryReportRow {
                RoomId=rd.GetInt32(0),RoomNo=rd.GetString(1),
                CampName=rd.IsDBNull(2)?"":rd.GetString(2), FloorName=rd.IsDBNull(3)?"":rd.GetString(3),
                Status=rd.GetString(4), Occupied=rd.GetBoolean(5), MonthlyPrice=rd.GetDecimal(6),
                TenantName=rd.IsDBNull(7)?"":rd.GetString(7), ContractId=rd.IsDBNull(8)?"":rd.GetString(8),
                ContractStatus=rd.IsDBNull(9)?"":rd.GetString(9), OtherDetails=rd.IsDBNull(10)?"":rd.GetString(10),
            });
        int total=all.Count, occ=all.Count(x=>x.Occupied||x.Status=="Occupied"), vac=all.Count(x=>x.Status=="Vacant");
        int pg=r.ResolvedPage, ps=r.ResolvedPageSize==int.MaxValue?all.Count:r.ResolvedPageSize;
        return new InventoryReportResponse {
            Summary=new(){TotalRooms=total,OccupiedRooms=occ,VacantRooms=vac,OccupancyRate=total>0?Math.Round((decimal)occ/total*100,1):0},
            StatusBreakdown=all.GroupBy(x=>x.Status).Select(g=>new InventoryStatusBreakdown{Status=g.Key,Count=g.Count()}).OrderByDescending(x=>x.Count).ToList(),
            CampBreakdown=all.GroupBy(x=>x.CampName).Select(g=>new InventoryCampBreakdown{CampName=g.Key,TotalRooms=g.Count(),OccupiedRooms=g.Count(x=>x.Occupied||x.Status=="Occupied"),VacantRooms=g.Count(x=>x.Status=="Vacant")}).OrderByDescending(x=>x.TotalRooms).ToList(),
            Rows=all.Skip((pg-1)*ps).Take(ps).ToList(), TotalRecords=total };
    }

    // ── Tenant Report ────────────────────────────────────────────────────────
    public async Task<TenantReportResponse> GetTenantReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTenantReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize",   int.MaxValue);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)r.CampId     ?? DBNull.Value);
        cmd.Parameters.Add(new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output });
        var all = new List<TenantReportRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) all.Add(new TenantReportRow {
                TenantId=rd.GetInt32(rd.GetOrdinal("TenantId")),
                TenantName=rd.GetString(rd.GetOrdinal("TenantName")),
                Contact=rd.IsDBNull(rd.GetOrdinal("Contact"))?"":rd.GetString(rd.GetOrdinal("Contact")),
                Email=rd.IsDBNull(rd.GetOrdinal("Email"))?"":rd.GetString(rd.GetOrdinal("Email")),
                EmiratesId=rd.IsDBNull(rd.GetOrdinal("EmiratesId"))?"":rd.GetString(rd.GetOrdinal("EmiratesId")),
                Nationality=rd.IsDBNull(rd.GetOrdinal("Nationality"))?"":rd.GetString(rd.GetOrdinal("Nationality")),
                Status=rd.GetString(rd.GetOrdinal("Status")),
                Type=rd.IsDBNull(rd.GetOrdinal("Type"))?"Individual":rd.GetString(rd.GetOrdinal("Type")),
                ContractId=rd.IsDBNull(rd.GetOrdinal("ContractId"))?"":rd.GetString(rd.GetOrdinal("ContractId")),
                CampName=rd.IsDBNull(rd.GetOrdinal("CampName"))?"":rd.GetString(rd.GetOrdinal("CampName")),
                RoomNo=rd.IsDBNull(rd.GetOrdinal("RoomNo"))?"":rd.GetString(rd.GetOrdinal("RoomNo")),
                ContractStart=rd.IsDBNull(rd.GetOrdinal("ContractStart"))?null:rd.GetDateTime(rd.GetOrdinal("ContractStart")),
                ContractEnd=rd.IsDBNull(rd.GetOrdinal("ContractEnd"))?null:rd.GetDateTime(rd.GetOrdinal("ContractEnd")),
                ContractStatus=rd.IsDBNull(rd.GetOrdinal("ContractStatus"))?"":rd.GetString(rd.GetOrdinal("ContractStatus")),
                MonthlyRent=rd.IsDBNull(rd.GetOrdinal("MonthlyRent"))?0:rd.GetDecimal(rd.GetOrdinal("MonthlyRent")),
                TotalAmount=rd.IsDBNull(rd.GetOrdinal("TotalAmount"))?0:rd.GetDecimal(rd.GetOrdinal("TotalAmount")),
                RoomsBooked=rd.IsDBNull(rd.GetOrdinal("RoomsBooked"))?0:rd.GetInt32(rd.GetOrdinal("RoomsBooked")),
                TotalPaid=rd.IsDBNull(rd.GetOrdinal("TotalPaid"))?0:rd.GetDecimal(rd.GetOrdinal("TotalPaid")),
                TotalDue=rd.IsDBNull(rd.GetOrdinal("TotalDue"))?0:rd.GetDecimal(rd.GetOrdinal("TotalDue")),
                Balance=rd.IsDBNull(rd.GetOrdinal("Balance"))?0:rd.GetDecimal(rd.GetOrdinal("Balance")),
                WaiverAmount=rd.IsDBNull(rd.GetOrdinal("WaiverAmount"))?0:rd.GetDecimal(rd.GetOrdinal("WaiverAmount")),
            });

        // Unique tenants (SP returns one row per contract — deduplicate by TenantId)
        var uniq = all.GroupBy(x => x.TenantId).Select(g => g.First()).ToList();
        int total     = uniq.Count;
        int active    = uniq.Count(x => x.Status == "Active");
        int inactive  = uniq.Count(x => x.Status != "Active");
        int companies = uniq.Count(x => x.Type == "Company");
        int indivs    = uniq.Count(x => x.Type == "Individual");

        int pg = r.ResolvedPage;
        int ps = r.ResolvedPageSize == int.MaxValue ? all.Count : r.ResolvedPageSize;

        return new TenantReportResponse {
            Summary = new TenantReportSummary {
                TotalTenants    = total,
                ActiveTenants   = active,
                InactiveTenants = inactive,
                Companies       = companies,
                Individuals     = indivs,
            },
            TypeBreakdown = new List<TenantTypeBreakdown> {
                new() { Type = "Individual", Count = indivs    },
                new() { Type = "Company",    Count = companies },
            },
            StatusBreakdown = new List<TenantStatusBreakdown> {
                new() { Status = "Active",   Count = active   },
                new() { Status = "Inactive", Count = inactive },
            },
            Rows         = all.Skip((pg-1)*ps).Take(ps).ToList(),
            TotalRecords = all.Count,
        };
    }

    // ── Partner Report ───────────────────────────────────────────────────────
    public async Task<PartnerReportResponse> GetPartnerReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPartnerReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize",   int.MaxValue);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.Add(new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output });
        var all = new List<PartnerReportRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) all.Add(new PartnerReportRow {
                PartnerId=rd.GetInt32(rd.GetOrdinal("PartnerId")),
                PartnerCode=rd.GetString(rd.GetOrdinal("PartnerCode")),
                PartnerName=rd.GetString(rd.GetOrdinal("PartnerName")),
                Contact=rd.IsDBNull(rd.GetOrdinal("Contact"))?"":rd.GetString(rd.GetOrdinal("Contact")),
                Mobile=rd.IsDBNull(rd.GetOrdinal("Mobile"))?"":rd.GetString(rd.GetOrdinal("Mobile")),
                Email=rd.IsDBNull(rd.GetOrdinal("Email"))?"":rd.GetString(rd.GetOrdinal("Email")),
                Status=rd.GetString(rd.GetOrdinal("Status")),
                TotalCamps=rd.IsDBNull(rd.GetOrdinal("TotalCamps"))?0:rd.GetInt32(rd.GetOrdinal("TotalCamps")),
                CampNames=rd.IsDBNull(rd.GetOrdinal("CampNames"))?"":rd.GetString(rd.GetOrdinal("CampNames")),
                ShareValue=rd.IsDBNull(rd.GetOrdinal("ShareValue"))?0:rd.GetDecimal(rd.GetOrdinal("ShareValue")),
                ShareType=rd.IsDBNull(rd.GetOrdinal("ShareType"))?"":rd.GetString(rd.GetOrdinal("ShareType")),
                TotalCollected=rd.IsDBNull(rd.GetOrdinal("TotalCollected"))?0:rd.GetDecimal(rd.GetOrdinal("TotalCollected")),
                TotalPaid=rd.IsDBNull(rd.GetOrdinal("TotalPaid"))?0:rd.GetDecimal(rd.GetOrdinal("TotalPaid")),
            });
        int total=all.Count, active=all.Count(x=>x.Status=="Active"), inactive=all.Count(x=>x.Status!="Active");
        var campMap = new Dictionary<string,int>();
        foreach(var p in all) foreach(var c in (p.CampNames??"").Split(',').Select(s=>s.Trim()).Where(s=>s!=""))
            campMap[c]=campMap.TryGetValue(c,out var v)?v+1:1;
        int pg=r.ResolvedPage, ps=r.ResolvedPageSize==int.MaxValue?all.Count:r.ResolvedPageSize;
        return new PartnerReportResponse {
            Summary=new(){TotalPartners=total,ActivePartners=active,InactivePartners=inactive,AssignedToCamps=all.Count(x=>x.TotalCamps>0)},
            CampBreakdown=campMap.Select(kv=>new PartnerCampCount{CampName=kv.Key,PartnerCount=kv.Value}).OrderByDescending(x=>x.PartnerCount).ToList(),
            Rows=all.Skip((pg-1)*ps).Take(ps).ToList(), TotalRecords=total };
    }

    // ── Camp Report ──────────────────────────────────────────────────────────
    public async Task<CampReportResponse> GetCampReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize",   int.MaxValue);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.Add(new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output });
        var all = new List<CampReportRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) all.Add(new CampReportRow {
                CampId=rd.GetInt32(rd.GetOrdinal("CampId")),
                CampCode=rd.GetString(rd.GetOrdinal("CampCode")),
                CampName=rd.GetString(rd.GetOrdinal("CampName")),
                Status=rd.GetString(rd.GetOrdinal("Status")),
                TotalRooms=rd.IsDBNull(rd.GetOrdinal("TotalRooms"))?0:rd.GetInt32(rd.GetOrdinal("TotalRooms")),
                OccupiedRooms=rd.IsDBNull(rd.GetOrdinal("OccupiedRooms"))?0:rd.GetInt32(rd.GetOrdinal("OccupiedRooms")),
                VacantRooms=rd.IsDBNull(rd.GetOrdinal("VacantRooms"))?0:rd.GetInt32(rd.GetOrdinal("VacantRooms")),
                ActiveContracts=rd.IsDBNull(rd.GetOrdinal("ActiveContracts"))?0:rd.GetInt32(rd.GetOrdinal("ActiveContracts")),
                TotalMonthlyRent=rd.IsDBNull(rd.GetOrdinal("TotalMonthlyRent"))?0:rd.GetDecimal(rd.GetOrdinal("TotalMonthlyRent")),
                TotalCollected=rd.IsDBNull(rd.GetOrdinal("TotalCollected"))?0:rd.GetDecimal(rd.GetOrdinal("TotalCollected")),
                TotalDue=rd.IsDBNull(rd.GetOrdinal("TotalDue"))?0:rd.GetDecimal(rd.GetOrdinal("TotalDue")),
                CampExpense=rd.IsDBNull(rd.GetOrdinal("CampExpense"))?0:rd.GetDecimal(rd.GetOrdinal("CampExpense")),
                HOAllocated=rd.IsDBNull(rd.GetOrdinal("HOAllocated"))?0:rd.GetDecimal(rd.GetOrdinal("HOAllocated")),
                TotalExpense=rd.IsDBNull(rd.GetOrdinal("TotalExpense"))?0:rd.GetDecimal(rd.GetOrdinal("TotalExpense")),
                Profit=rd.IsDBNull(rd.GetOrdinal("Profit"))?0:rd.GetDecimal(rd.GetOrdinal("Profit")),
            });
        int total=all.Count, active=all.Count(x=>x.Status=="Active"), rooms=all.Sum(x=>x.TotalRooms);
        int pg=r.ResolvedPage, ps=r.ResolvedPageSize==int.MaxValue?all.Count:r.ResolvedPageSize;
        return new CampReportResponse {
            Summary=new(){TotalCamps=total,ActiveCamps=active,TotalRooms=rooms,AvgRoomsPerCamp=total>0?(int)Math.Round((double)rooms/total):0},
            ChartData=all.Select(x=>new CampChartBar{CampName=x.CampName,MonthlyRent=x.TotalMonthlyRent,Collected=x.TotalCollected,Outstanding=x.TotalDue}).ToList(),
            Rows=all.Skip((pg-1)*ps).Take(ps).ToList(), TotalRecords=total };
    }

    // ── Waiver Report ────────────────────────────────────────────────────────
    public async Task<WaiverReportResponse> GetWaiverReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetWaiverReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize",   int.MaxValue);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",   (object?)r.TenantId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)r.DateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)r.DateTo     ?? DBNull.Value);
        cmd.Parameters.Add(new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output });
        var all = new List<WaiverReportRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) all.Add(new WaiverReportRow {
                WaiverId=rd.GetInt32(rd.GetOrdinal("WaiverId")),
                TenantId=rd.GetInt32(rd.GetOrdinal("TenantId")),
                TenantName=rd.GetString(rd.GetOrdinal("TenantName")),
                ContractId=rd.GetString(rd.GetOrdinal("ContractId")),
                InstallmentNo=rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                OriginalAmount=rd.GetDecimal(rd.GetOrdinal("OriginalAmount")),
                WaiverAmount=rd.GetDecimal(rd.GetOrdinal("WaiverAmount")),
                BalanceAmount=rd.GetDecimal(rd.GetOrdinal("BalanceAmount")),
                Remark=rd.IsDBNull(rd.GetOrdinal("Remark"))?"":rd.GetString(rd.GetOrdinal("Remark")),
                WaiverDate=rd.GetDateTime(rd.GetOrdinal("WaiverDate")),
            });
        int total=all.Count; decimal totalAmt=all.Sum(x=>x.WaiverAmount);
        var months=new[]{"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
        var monthly=months.Select((m,i)=>new WaiverMonthlyData{Month=m,Amount=all.Where(x=>x.WaiverDate.Month==i+1).Sum(x=>x.WaiverAmount)}).ToList();
        var tenantMap=all.GroupBy(x=>x.TenantName).Select(g=>new WaiverTenantData{TenantName=g.Key,Amount=g.Sum(x=>x.WaiverAmount)}).OrderByDescending(x=>x.Amount).Take(6).ToList();
        int pg=r.ResolvedPage, ps=r.ResolvedPageSize==int.MaxValue?all.Count:r.ResolvedPageSize;
        return new WaiverReportResponse {
            Summary=new(){TotalWaivers=total,TotalAmount=totalAmt,AvgAmount=total>0?Math.Round(totalAmt/total,2):0,UniqueTenants=all.Select(x=>x.TenantId).Distinct().Count()},
            MonthlyData=monthly, TenantBreakdown=tenantMap,
            Rows=all.Skip((pg-1)*ps).Take(ps).ToList(), TotalRecords=total };
    }

    // ── Transaction Statement ─────────────────────────────────────────────────
    public async Task<TransactionReportResponse> GetTransactionStatementAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTransactionStatement", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize",   int.MaxValue);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)r.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractId",  (object?)r.ContractId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",    (object?)r.TenantId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",      (object?)r.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      (object?)r.Status      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",    (object?)r.DateFrom    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",      (object?)r.DateTo      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",       (object?)r.Month       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Year",        (object?)r.Year        ?? DBNull.Value);
        cmd.Parameters.Add(new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output });
        var all = new List<TransactionRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) all.Add(new TransactionRow {
                Id=rd.GetInt32(rd.GetOrdinal("Id")),
                Date=rd.IsDBNull(rd.GetOrdinal("Date"))?DateTime.MinValue:rd.GetDateTime(rd.GetOrdinal("Date")),
                ContractId=rd.IsDBNull(rd.GetOrdinal("ContractId"))?"":rd.GetString(rd.GetOrdinal("ContractId")),
                TenantName=rd.IsDBNull(rd.GetOrdinal("TenantName"))?"":rd.GetString(rd.GetOrdinal("TenantName")),
                CampName=rd.IsDBNull(rd.GetOrdinal("CampName"))?"":rd.GetString(rd.GetOrdinal("CampName")),
                RoomNo="",
                InstallmentNo=0,
                Amount=rd.IsDBNull(rd.GetOrdinal("Amount"))?0:rd.GetDecimal(rd.GetOrdinal("Amount")),
                PaidAmount=rd.IsDBNull(rd.GetOrdinal("Amount"))?0:rd.GetDecimal(rd.GetOrdinal("Amount")),
                Balance=0,
                PaymentMode=rd.IsDBNull(rd.GetOrdinal("Mode"))?"":rd.GetString(rd.GetOrdinal("Mode")),
                Status=rd.IsDBNull(rd.GetOrdinal("Status"))?"":rd.GetString(rd.GetOrdinal("Status")),
                ReceivedBy="",
                FundPoolName=rd.IsDBNull(rd.GetOrdinal("FundPoolName"))?"":rd.GetString(rd.GetOrdinal("FundPoolName")),
                ChequeNumber="",
                // Extra fields from new SP
                AccountHead=rd.IsDBNull(rd.GetOrdinal("AccountHead"))?"":rd.GetString(rd.GetOrdinal("AccountHead")),
                Particular=rd.IsDBNull(rd.GetOrdinal("Particular"))?"":rd.GetString(rd.GetOrdinal("Particular")),
                TxnType=rd.IsDBNull(rd.GetOrdinal("TxnType"))?"":rd.GetString(rd.GetOrdinal("TxnType")),
                Source=rd.IsDBNull(rd.GetOrdinal("Source"))?"":rd.GetString(rd.GetOrdinal("Source")),
            });
        var paid=all.Where(x=>x.Status=="Paid").ToList();
        decimal totalIncome=paid.Sum(x=>x.PaidAmount);
        var months=new[]{"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
        var monthly=months.Select((m,i)=>new TransactionMonthlyData{Month=m,
            Income=paid.Where(x=>x.Date.Month==i+1).Sum(x=>x.PaidAmount), Expenses=0}).ToList();
        int pg=r.ResolvedPage, ps=r.ResolvedPageSize==int.MaxValue?all.Count:r.ResolvedPageSize;
        return new TransactionReportResponse {
            Summary=new(){TotalCount=all.Count,TotalIncome=totalIncome,PaidCount=paid.Count,PendingCount=all.Count(x=>x.Status=="Pending")},
            MonthlyData=monthly,
            Rows=all.Skip((pg-1)*ps).Take(ps).ToList(), TotalRecords=all.Count };
    }

    // ── Tenant Ledger ─────────────────────────────────────────────────────────
    public async Task<TenantLedgerSummary?> GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTenantLedger", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TenantId",   tenantId);
        cmd.Parameters.AddWithValue("@ContractId", (object?)contractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)dateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)dateTo     ?? DBNull.Value);
        await using var rd = await cmd.ExecuteReaderAsync();
        if (!await rd.ReadAsync()) return null;
        var summary = new TenantLedgerSummary {
            TenantName=rd.IsDBNull(rd.GetOrdinal("TenantName"))?"":rd.GetString(rd.GetOrdinal("TenantName")),
            Contact=rd.IsDBNull(rd.GetOrdinal("Contact"))?"":rd.GetString(rd.GetOrdinal("Contact")),
            TotalDebit=rd.IsDBNull(rd.GetOrdinal("TotalDebit"))?0:rd.GetDecimal(rd.GetOrdinal("TotalDebit")),
            TotalCredit=rd.IsDBNull(rd.GetOrdinal("TotalCredit"))?0:rd.GetDecimal(rd.GetOrdinal("TotalCredit")),
            NetBalance=rd.IsDBNull(rd.GetOrdinal("NetBalance"))?0:rd.GetDecimal(rd.GetOrdinal("NetBalance")),
        };
        await rd.NextResultAsync();
        int serial=0;
        while (await rd.ReadAsync()) summary.Rows.Add(new TenantLedgerRow {
            SerialNo=++serial,
            Date=rd.GetDateTime(rd.GetOrdinal("Date")),
            Description=rd.IsDBNull(rd.GetOrdinal("Description"))?"":rd.GetString(rd.GetOrdinal("Description")),
            Type=rd.IsDBNull(rd.GetOrdinal("Type"))?"":rd.GetString(rd.GetOrdinal("Type")),
            Debit=rd.IsDBNull(rd.GetOrdinal("Debit"))?0:rd.GetDecimal(rd.GetOrdinal("Debit")),
            Credit=rd.IsDBNull(rd.GetOrdinal("Credit"))?0:rd.GetDecimal(rd.GetOrdinal("Credit")),
            Balance=rd.IsDBNull(rd.GetOrdinal("Balance"))?0:rd.GetDecimal(rd.GetOrdinal("Balance")),
            ContractId=rd.IsDBNull(rd.GetOrdinal("ContractId"))?"":rd.GetString(rd.GetOrdinal("ContractId")),
            InstallmentNo=rd.IsDBNull(rd.GetOrdinal("InstallmentNo"))?0:rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
            PaymentMode=rd.IsDBNull(rd.GetOrdinal("PaymentMode"))?"":rd.GetString(rd.GetOrdinal("PaymentMode")),
            Reference=rd.IsDBNull(rd.GetOrdinal("Reference"))?"":rd.GetString(rd.GetOrdinal("Reference")),
        });
        return summary;
    }

    // ── Monthly Due Report ────────────────────────────────────────────────────
    public async Task<DueReportResponse> GetDueReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Build WHERE conditions
        var where = new List<string> { "ci.Status IN ('Pending','Partial')" };
        if (r.TenantId.HasValue) where.Add("ct.TenantId=@TenantId");
        if (r.CampId.HasValue)   where.Add("ct.CampId=@CampId");
        if (!string.IsNullOrEmpty(r.Month))
        {
            var parts = r.Month.Split('-');
            if (parts.Length == 2)
            {
                where.Add("FORMAT(ci.DueDate,'yyyy-MM')=@Month");
            }
        }
        var whereClause = "WHERE " + string.Join(" AND ", where);

        var sql = $@"
            SELECT
                ci.Id, ci.ContractId, ci.InstallmentNo,
                ci.Amount, ci.PaidAmount,
                ci.Amount - ci.PaidAmount  BalanceAmount,
                ci.DueDate, ci.Status,
                ISNULL(ci.PaymentMode,'')  PaymentMode,
                ISNULL(t.Name,'')          TenantName,
                ct.TenantId,
                ISNULL(ca.Name,'')         CampName,
                ISNULL(rm.RoomNo,'')       RoomNo,
                CASE WHEN ci.DueDate < GETDATE() THEN 'Overdue' ELSE 'Pending' END DueStatus
            FROM ContractInstallments ci
            JOIN Contracts ct ON ct.ContractId=ci.ContractId
            LEFT JOIN Tenants t  ON t.Id=ct.TenantId
            LEFT JOIN Camps ca   ON ca.Id=ct.CampId
            LEFT JOIN ContractRooms cr ON cr.ContractId=ci.ContractId
            LEFT JOIN Rooms rm   ON rm.Id=cr.RoomId
            {whereClause}
            ORDER BY ci.DueDate";

        var allRows = new List<DueReportRow>();
        await using (var cmd = new SqlCommand(sql, conn))
        {
            if (r.TenantId.HasValue) cmd.Parameters.AddWithValue("@TenantId", r.TenantId.Value);
            if (r.CampId.HasValue)   cmd.Parameters.AddWithValue("@CampId",   r.CampId.Value);
            if (!string.IsNullOrEmpty(r.Month)) cmd.Parameters.AddWithValue("@Month", r.Month);
            cmd.CommandTimeout = 60;
            await using var rd = await cmd.ExecuteReaderAsync();
            while (await rd.ReadAsync())
                allRows.Add(new DueReportRow {
                    Id            = rd.GetInt32(rd.GetOrdinal("Id")),
                    ContractId    = rd.IsDBNull(rd.GetOrdinal("ContractId"))   ? "" : rd.GetString(rd.GetOrdinal("ContractId")),
                    TenantName    = rd.IsDBNull(rd.GetOrdinal("TenantName"))   ? "" : rd.GetString(rd.GetOrdinal("TenantName")),
                    TenantId      = rd.IsDBNull(rd.GetOrdinal("TenantId"))     ? 0  : rd.GetInt32(rd.GetOrdinal("TenantId")),
                    CampName      = rd.IsDBNull(rd.GetOrdinal("CampName"))     ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    RoomNo        = rd.IsDBNull(rd.GetOrdinal("RoomNo"))       ? "" : rd.GetString(rd.GetOrdinal("RoomNo")),
                    InstallmentNo = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                    Amount        = rd.GetDecimal(rd.GetOrdinal("Amount")),
                    PaidAmount    = rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                    BalanceAmount = rd.GetDecimal(rd.GetOrdinal("BalanceAmount")),
                    DueDate       = rd.GetDateTime(rd.GetOrdinal("DueDate")),
                    Status        = rd.GetString(rd.GetOrdinal("Status")),
                    DueStatus     = rd.IsDBNull(rd.GetOrdinal("DueStatus"))    ? "" : rd.GetString(rd.GetOrdinal("DueStatus")),
                    PaymentMode   = rd.IsDBNull(rd.GetOrdinal("PaymentMode"))  ? "" : rd.GetString(rd.GetOrdinal("PaymentMode")),
                });
        }

        // Summary
        int total        = allRows.Count;
        decimal totalDue = allRows.Sum(x => x.BalanceAmount);
        int overdueCount = allRows.Count(x => x.DueStatus == "Overdue");
        decimal avg      = total > 0 ? Math.Round(totalDue / total, 2) : 0;

        // Bar chart — monthly due distribution
        var monthNames = new[] {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
        var monthly = monthNames.Select((m, i) => new DueMonthlyData {
            Month  = m,
            Amount = allRows.Where(x => x.DueDate.Month == i+1).Sum(x => x.BalanceAmount)
        }).ToList();

        // Pie chart — Current Due vs Overdue
        var statusData = new List<DueStatusData> {
            new() { Status = "Current Due", Count = total - overdueCount },
            new() { Status = "Overdue",     Count = overdueCount },
        };

        int pg = r.ResolvedPage;
        int ps = r.ResolvedPageSize == int.MaxValue ? allRows.Count : r.ResolvedPageSize;

        return new DueReportResponse {
            Summary     = new DueReportSummary { TotalDueAmount=totalDue, TotalCount=total, OverdueCount=overdueCount, AvgDueAmount=avg },
            MonthlyData = monthly,
            StatusData  = statusData,
            Rows        = allRows.Skip((pg-1)*ps).Take(ps).ToList(),
            TotalRecords= total,
        };
    }

    // ── Room History ──────────────────────────────────────────────────────────
    public async Task<IEnumerable<RoomHistoryRow>> GetRoomHistoryAsync(int roomId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetRoomHistory", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@RoomId", roomId);
        var list = new List<RoomHistoryRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new RoomHistoryRow {
            ContractId=rd.GetString(rd.GetOrdinal("ContractId")),
            TenantName=rd.GetString(rd.GetOrdinal("TenantName")),
            StartDate=rd.GetDateTime(rd.GetOrdinal("StartDate")),
            EndDate=rd.GetDateTime(rd.GetOrdinal("EndDate")),
            MonthlyRent=rd.GetDecimal(rd.GetOrdinal("MonthlyRent")),
            Status=rd.GetString(rd.GetOrdinal("Status")),
        });
        return list;
    }

    // ── Make Payment ──────────────────────────────────────────────────────────
    public async Task<int> MakePaymentAsync(MakePaymentRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_MakePayment", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PaymentType",   request.PaymentType);
        cmd.Parameters.AddWithValue("@RecipientId",   (object?)request.RecipientId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientName", request.RecipientName);
        cmd.Parameters.AddWithValue("@Amount",        request.Amount);
        cmd.Parameters.AddWithValue("@PaymentDate",   request.PaymentDate);
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)request.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",   request.PaymentMode);
        cmd.Parameters.AddWithValue("@Description",   request.Description);
        cmd.Parameters.AddWithValue("@FundPoolId",    (object?)request.FundPoolId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Reference",     request.Reference);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHeadId", (object?)request.AccountHeadId ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<(IEnumerable<MakePaymentResponse> Data, int Total)> GetOutgoingPaymentsAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOutgoingPayments", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)r.DateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)r.DateTo     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<MakePaymentResponse>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new MakePaymentResponse {
            Id=rd.GetInt32(rd.GetOrdinal("Id")),
            PaymentCode=rd.GetString(rd.GetOrdinal("PaymentCode")),
            PaymentType=rd.GetString(rd.GetOrdinal("PaymentType")),
            RecipientName=rd.GetString(rd.GetOrdinal("RecipientName")),
            Amount=rd.GetDecimal(rd.GetOrdinal("Amount")),
            PaymentDate=rd.GetDateTime(rd.GetOrdinal("PaymentDate")),
            PaymentMode=rd.IsDBNull(rd.GetOrdinal("PaymentMode"))?"":rd.GetString(rd.GetOrdinal("PaymentMode")),
            Description=rd.IsDBNull(rd.GetOrdinal("Description"))?"":rd.GetString(rd.GetOrdinal("Description")),
            FundPoolName=rd.IsDBNull(rd.GetOrdinal("FundPoolName"))?"":rd.GetString(rd.GetOrdinal("FundPoolName")),
            Reference=rd.IsDBNull(rd.GetOrdinal("Reference"))?"":rd.GetString(rd.GetOrdinal("Reference")),
            CreatedAt=rd.GetDateTime(rd.GetOrdinal("CreatedAt")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }
}
