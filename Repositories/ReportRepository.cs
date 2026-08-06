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
                RoomId=rd.GetInt32(rd.GetOrdinal("RoomId")),
                RoomNo=rd.GetString(rd.GetOrdinal("RoomNo")),
                CampName=rd.IsDBNull(rd.GetOrdinal("CampName"))?"":rd.GetString(rd.GetOrdinal("CampName")),
                FloorName=rd.IsDBNull(rd.GetOrdinal("FloorName"))?"":rd.GetString(rd.GetOrdinal("FloorName")),
                Status=rd.GetString(rd.GetOrdinal("Status")),
                Occupied=rd.GetBoolean(rd.GetOrdinal("Occupied")),
                MonthlyPrice=rd.GetDecimal(rd.GetOrdinal("MonthlyPrice")),
                OtherDetails=rd.IsDBNull(rd.GetOrdinal("OtherDetails"))?"":rd.GetString(rd.GetOrdinal("OtherDetails")),
                TenantName=rd.IsDBNull(rd.GetOrdinal("TenantName"))?"":rd.GetString(rd.GetOrdinal("TenantName")),
                ContractId=rd.IsDBNull(rd.GetOrdinal("ContractId"))?"":rd.GetString(rd.GetOrdinal("ContractId")),
                ContractStatus=rd.IsDBNull(rd.GetOrdinal("ContractStatus"))?"":rd.GetString(rd.GetOrdinal("ContractStatus")),
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
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize == int.MaxValue ? 100 : r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)r.CampId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",   (object?)r.TenantId   ?? DBNull.Value);
        var pTotal = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pTotal);
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
                
                // Security Deposit Info
                SecurityDeposit=rd.IsDBNull(rd.GetOrdinal("SecurityDeposit"))?0:rd.GetDecimal(rd.GetOrdinal("SecurityDeposit")),
                SecurityDepositStatus=rd.IsDBNull(rd.GetOrdinal("SecurityDepositStatus"))?"Pending":rd.GetString(rd.GetOrdinal("SecurityDepositStatus")),
                SecurityDepositPaid=rd.IsDBNull(rd.GetOrdinal("SecurityDepositPaid"))?0:rd.GetDecimal(rd.GetOrdinal("SecurityDepositPaid")),
                // SD Settlement
                SdRefundAmount =rd.IsDBNull(rd.GetOrdinal("SdRefundAmount")) ?0:rd.GetDecimal(rd.GetOrdinal("SdRefundAmount")),
                SdForfeitAmount=rd.IsDBNull(rd.GetOrdinal("SdForfeitAmount"))?0:rd.GetDecimal(rd.GetOrdinal("SdForfeitAmount")),
                SdAdjustAmount =rd.IsDBNull(rd.GetOrdinal("SdAdjustAmount")) ?0:rd.GetDecimal(rd.GetOrdinal("SdAdjustAmount")),
                
                // Multiple Camps Support
                CampsCount=rd.IsDBNull(rd.GetOrdinal("CampsCount"))?0:rd.GetInt32(rd.GetOrdinal("CampsCount")),
                
                // Rent Amounts
                MonthlyRent=rd.IsDBNull(rd.GetOrdinal("MonthlyRent"))?0:rd.GetDecimal(rd.GetOrdinal("MonthlyRent")),
                ContractRentTotal=rd.IsDBNull(rd.GetOrdinal("ContractRentTotal"))?0:rd.GetDecimal(rd.GetOrdinal("ContractRentTotal")),
                TotalAmount=rd.IsDBNull(rd.GetOrdinal("TotalAmount"))?0:rd.GetDecimal(rd.GetOrdinal("TotalAmount")),   // RentTotal + SecurityDeposit
                
                // Room Info
                RoomsBooked=rd.IsDBNull(rd.GetOrdinal("RoomsBooked"))?0:rd.GetInt32(rd.GetOrdinal("RoomsBooked")),
                
                // Payment Breakdown (TxnRecords based)
                RentPaid=rd.IsDBNull(rd.GetOrdinal("RentPaid"))?0:rd.GetDecimal(rd.GetOrdinal("RentPaid")),
                SecurityDepositPaidAmount=rd.IsDBNull(rd.GetOrdinal("SecurityDepositPaidAmount"))?0:rd.GetDecimal(rd.GetOrdinal("SecurityDepositPaidAmount")),
                TotalPaid=rd.IsDBNull(rd.GetOrdinal("TotalPaid"))?0:rd.GetDecimal(rd.GetOrdinal("TotalPaid")),
                TotalDue=rd.IsDBNull(rd.GetOrdinal("TotalDue"))?0:rd.GetDecimal(rd.GetOrdinal("TotalDue")),
                
                // Waiver Info
                WaiverAmount=rd.IsDBNull(rd.GetOrdinal("WaiverAmount"))?0:rd.GetDecimal(rd.GetOrdinal("WaiverAmount")),
            });

        // Calculate Balance: TotalDue - WaiverAmount
        foreach (var row in all)
        {
            row.Balance = row.TotalDue - row.WaiverAmount;
        }

        // Summary cards — unique tenants (not contracts)
        var uniqTenants = all.GroupBy(x => x.TenantId).Select(g => g.First()).ToList();
        int total     = uniqTenants.Count;
        int active    = uniqTenants.Count(x => x.Status == "Active");
        int inactive  = uniqTenants.Count(x => x.Status != "Active");
        int companies = uniqTenants.Count(x => x.Type == "Company");
        int indivs    = uniqTenants.Count(x => x.Type != "Company");

        // SP already applies pagination — rows are ready
        int totalRecords = pTotal.Value != DBNull.Value ? (int)pTotal.Value : all.Count;

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
            Rows         = all,
            TotalRecords = totalRecords,
        };
    }

    // ── Partner Report ───────────────────────────────────────────────────────
    public async Task<PartnerReportResponse> GetPartnerReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPartnerReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize == int.MaxValue ? 100 : r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        var pPartnerTotal = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pPartnerTotal);
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
                ShareDue=rd.IsDBNull(rd.GetOrdinal("ShareDue"))?0:rd.GetDecimal(rd.GetOrdinal("ShareDue")),
            });
        int total=all.Count, active=all.Count(x=>x.Status=="Active"), inactive=all.Count(x=>x.Status!="Active");
        var campMap = new Dictionary<string,int>();
        foreach(var p in all) foreach(var c in (p.CampNames??"").Split(',').Select(s=>s.Trim()).Where(s=>s!=""))
            campMap[c]=campMap.TryGetValue(c,out var v)?v+1:1;
        int totalPartnerRecords = pPartnerTotal.Value != DBNull.Value ? (int)pPartnerTotal.Value : all.Count;
        return new PartnerReportResponse {
            Summary=new(){TotalPartners=totalPartnerRecords,ActivePartners=active,InactivePartners=inactive,AssignedToCamps=all.Count(x=>x.TotalCamps>0)},
            CampBreakdown=campMap.Select(kv=>new PartnerCampCount{CampName=kv.Key,PartnerCount=kv.Value}).OrderByDescending(x=>x.PartnerCount).ToList(),
            Rows=all, TotalRecords=totalPartnerRecords };
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
                RoomNo="", InstallmentNo=0,
                Amount=rd.IsDBNull(rd.GetOrdinal("Amount"))?0:rd.GetDecimal(rd.GetOrdinal("Amount")),
                PaidAmount=rd.IsDBNull(rd.GetOrdinal("Amount"))?0:rd.GetDecimal(rd.GetOrdinal("Amount")),
                Balance=0,
                PaymentMode=rd.IsDBNull(rd.GetOrdinal("Mode"))?"":rd.GetString(rd.GetOrdinal("Mode")),
                Status=rd.IsDBNull(rd.GetOrdinal("Status"))?"":rd.GetString(rd.GetOrdinal("Status")),
                ReceivedBy="",
                FundPoolName=rd.IsDBNull(rd.GetOrdinal("FundPoolName"))?"":rd.GetString(rd.GetOrdinal("FundPoolName")),
                ChequeNumber="",
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
            Summary=new TransactionReportSummaryCards{NoOfPayments=all.Count,TotalIncome=totalIncome,TotalExpense=0,TotalAmount=totalIncome},
            Rows=all.Select(x=>new TransactionReportRow{Id=x.Id,Date=x.Date,AccountHead=x.AccountHead,PartyRecipient=x.Particular,CampName=x.CampName,FundPoolName=x.FundPoolName,Type=x.TxnType,Source=x.Source,Mode=x.PaymentMode,Amount=x.Amount,Role="",RefId=x.ContractId}).Skip((pg-1)*ps).Take(ps).ToList(),
            TotalRecords=all.Count };
    }

    // ── Transaction Report (Income + Expense tables) ──────────────────────────
    public async Task<TransactionReportResponse> GetTransactionReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTransactionReport", conn) { CommandType = CommandType.StoredProcedure };
        int pageSize = r.ResolvedPageSize == int.MaxValue ? 2147483647 : r.ResolvedPageSize;
        cmd.Parameters.AddWithValue("@PageNumber",   r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",     pageSize);
        cmd.Parameters.AddWithValue("@DateFrom",     (object?)r.DateFrom    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",       (object?)r.DateTo      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHead",  (object?)r.AccountHead ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Party",        (object?)r.Party       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",       (object?)r.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPool",     (object?)r.FundPool    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Type",         (object?)r.Type        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Source",       (object?)r.Source      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode",         (object?)r.Mode        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Role",         (object?)r.Role        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",   (object?)r.SearchText  ?? DBNull.Value);
        var pTotal = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pTotal);

        var rows  = new List<TransactionReportRow>();
        var cards = new TransactionReportSummaryCards();

        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            // Result set 1: rows
            while (await rd.ReadAsync())
                rows.Add(new TransactionReportRow {
                    Id             = rd.IsDBNull(rd.GetOrdinal("Id"))             ? 0                : rd.GetInt32(rd.GetOrdinal("Id")),
                    Date           = rd.IsDBNull(rd.GetOrdinal("Date"))           ? DateTime.MinValue : rd.GetDateTime(rd.GetOrdinal("Date")),
                    AccountHead    = rd.IsDBNull(rd.GetOrdinal("AccountHead"))    ? "" : rd.GetString(rd.GetOrdinal("AccountHead")),
                    PartyRecipient = rd.IsDBNull(rd.GetOrdinal("PartyRecipient")) ? "" : rd.GetString(rd.GetOrdinal("PartyRecipient")),
                    CampName       = rd.IsDBNull(rd.GetOrdinal("CampName"))       ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    FundPool       = rd.IsDBNull(rd.GetOrdinal("FundPool"))       ? "" : rd.GetString(rd.GetOrdinal("FundPool")),
                    FundPoolName   = rd.IsDBNull(rd.GetOrdinal("FundPoolName"))   ? "" : rd.GetString(rd.GetOrdinal("FundPoolName")),
                    Type           = rd.IsDBNull(rd.GetOrdinal("Type"))           ? "" : rd.GetString(rd.GetOrdinal("Type")),
                    Source         = rd.IsDBNull(rd.GetOrdinal("Source"))         ? "" : rd.GetString(rd.GetOrdinal("Source")),
                    Mode           = rd.IsDBNull(rd.GetOrdinal("Mode"))           ? "" : rd.GetString(rd.GetOrdinal("Mode")),
                    Amount         = rd.IsDBNull(rd.GetOrdinal("Amount"))         ? 0  : rd.GetDecimal(rd.GetOrdinal("Amount")),
                    Role           = rd.IsDBNull(rd.GetOrdinal("Role"))           ? "" : rd.GetString(rd.GetOrdinal("Role")),
                    RefId          = rd.IsDBNull(rd.GetOrdinal("RefId"))          ? "" : rd.GetString(rd.GetOrdinal("RefId")),
                });

            // Result set 2: summary cards
            await rd.NextResultAsync();
            if (await rd.ReadAsync())
                cards = new TransactionReportSummaryCards {
                    NoOfPayments = rd.IsDBNull(rd.GetOrdinal("NoOfPayments")) ? 0 : rd.GetInt32(rd.GetOrdinal("NoOfPayments")),
                    TotalIncome  = rd.IsDBNull(rd.GetOrdinal("TotalIncome"))  ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalIncome")),
                    TotalExpense = rd.IsDBNull(rd.GetOrdinal("TotalExpense")) ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalExpense")),
                    TotalAmount  = rd.IsDBNull(rd.GetOrdinal("TotalAmount"))  ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalAmount")),
                };
        }

        int totalRecords = pTotal.Value != DBNull.Value ? (int)pTotal.Value : rows.Count;
        return new TransactionReportResponse {
            Summary      = cards,
            Rows         = rows,
            TotalRecords = totalRecords,
        };
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
        var where  = new List<string> { "ci.Status IN ('Pending','Partial','Overdue')" };
        var params_ = new List<SqlParameter>();

        if (r.TenantId.HasValue)
        {
            where.Add("ct.TenantId = @TenantId");
            params_.Add(new SqlParameter("@TenantId", r.TenantId.Value));
        }
        if (r.CampId.HasValue)
        {
            where.Add("ct.ContractId IN (SELECT ContractId FROM ContractCamps WHERE CampId = @CampId)");
            params_.Add(new SqlParameter("@CampId", r.CampId.Value));
        }
        if (!string.IsNullOrEmpty(r.ContractId))
        {
            where.Add("ci.ContractId = @ContractId");
            params_.Add(new SqlParameter("@ContractId", r.ContractId));
        }
        if (!string.IsNullOrEmpty(r.Month))
        {
            where.Add("FORMAT(ci.DueDate,'yyyy-MM') = @Month");
            params_.Add(new SqlParameter("@Month", r.Month));
        }
        if (!string.IsNullOrEmpty(r.DateFrom))
        {
            where.Add("ci.DueDate >= @DateFrom");
            params_.Add(new SqlParameter("@DateFrom", r.DateFrom));
        }
        if (!string.IsNullOrEmpty(r.DateTo))
        {
            where.Add("ci.DueDate <= @DateTo");
            params_.Add(new SqlParameter("@DateTo", r.DateTo));
        }
        if (!string.IsNullOrEmpty(r.Status))
        {
            // Status filter: Overdue or Pending
            if (r.Status == "Overdue")
                where.Add("ci.DueDate < GETDATE()");
            else if (r.Status == "Pending")
                where.Add("ci.DueDate >= GETDATE()");
        }
        if (!string.IsNullOrEmpty(r.SearchText))
        {
            where.Add("(t.Name LIKE @SearchText OR ci.ContractId LIKE @SearchText OR ca2sub.Name LIKE @SearchText)");
            params_.Add(new SqlParameter("@SearchText", $"%{r.SearchText}%"));
        }
        if (!string.IsNullOrEmpty(r.Mode))
        {
            where.Add("ISNULL(ci.PaymentMode,'') = @Mode");
            params_.Add(new SqlParameter("@Mode", r.Mode));
        }

        var whereClause = "WHERE " + string.Join(" AND ", where);

        var sql = $@"
            SELECT
                ci.Id, ci.ContractId, ci.InstallmentNo,
                ci.Amount, ci.PaidAmount,
                ci.Amount - ci.PaidAmount              BalanceAmount,
                ci.DueDate, ci.Status,
                ISNULL(ci.PaymentMode,'')              PaymentMode,
                ISNULL(t.Name,'')                      TenantName,
                ct.TenantId,
                ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2
                         JOIN Camps ca2 ON ca2.Id=cc2.CampId
                         WHERE cc2.ContractId=ct.ContractId
                         ORDER BY cc2.Id),'')          CampName,
                ISNULL(rm.RoomNo,'')                   RoomNo,
                CASE WHEN ci.DueDate < GETDATE() THEN 'Overdue' ELSE 'Pending' END DueStatus
            FROM ContractInstallments ci
            JOIN Contracts ct          ON ct.ContractId = ci.ContractId
            LEFT JOIN Tenants t        ON t.Id = ct.TenantId
            LEFT JOIN (SELECT DISTINCT ContractId,
                              (SELECT TOP 1 ca2.Name FROM ContractCamps cc2
                               JOIN Camps ca2 ON ca2.Id=cc2.CampId
                               WHERE cc2.ContractId=ci2.ContractId
                               ORDER BY cc2.Id) Name
                       FROM ContractInstallments ci2) ca2sub
                   ON ca2sub.ContractId = ci.ContractId
            LEFT JOIN ContractRooms cr ON cr.ContractId = ci.ContractId
            LEFT JOIN Rooms rm         ON rm.Id = cr.RoomId
            {whereClause}
            ORDER BY ci.DueDate";

        var allRows = new List<DueReportRow>();
        await using (var cmd = new SqlCommand(sql, conn))
        {
            foreach (var p in params_) cmd.Parameters.Add(p);
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

    // ── Camp Collection Report ────────────────────────────────────────────────
    public async Task<CampCollectionReportResponse> GetCampCollectionReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampCollectionReport", conn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 2400 };
        cmd.Parameters.AddWithValue("@CampId",     (object?)r.CampId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PartnerId",  (object?)r.PartnerId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@OwnerId",    (object?)r.OwnerId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractId", (object?)r.ContractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)r.DateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)r.DateTo     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",      (object?)r.Month      ?? DBNull.Value);
        var pTotal = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pTotal);

        var rows    = new List<CampCollectionRow>();
        var subTotal= new CampCollectionSubTotal();

        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            // Result set 1: rows
            while (await rd.ReadAsync())
                rows.Add(new CampCollectionRow {
                    CampId          = rd.IsDBNull(rd.GetOrdinal("CampId"))          ? 0  : rd.GetInt32(rd.GetOrdinal("CampId")),
                    CampCode        = rd.IsDBNull(rd.GetOrdinal("CampCode"))        ? "" : rd.GetString(rd.GetOrdinal("CampCode")),
                    CampName        = rd.IsDBNull(rd.GetOrdinal("CampName"))        ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    CampStatus      = rd.IsDBNull(rd.GetOrdinal("CampStatus"))      ? "" : rd.GetString(rd.GetOrdinal("CampStatus")),
                    TotalRooms      = rd.IsDBNull(rd.GetOrdinal("TotalRooms"))      ? 0  : rd.GetInt32(rd.GetOrdinal("TotalRooms")),
                    OccupiedRooms   = rd.IsDBNull(rd.GetOrdinal("OccupiedRooms"))   ? 0  : rd.GetInt32(rd.GetOrdinal("OccupiedRooms")),
                    VacantRooms     = rd.IsDBNull(rd.GetOrdinal("VacantRooms"))     ? 0  : rd.GetInt32(rd.GetOrdinal("VacantRooms")),
                    TotalContracts  = rd.IsDBNull(rd.GetOrdinal("TotalContracts"))  ? 0  : rd.GetInt32(rd.GetOrdinal("TotalContracts")),
                    ActiveContracts = rd.IsDBNull(rd.GetOrdinal("ActiveContracts")) ? 0  : rd.GetInt32(rd.GetOrdinal("ActiveContracts")),
                    TotalAmount     = rd.IsDBNull(rd.GetOrdinal("TotalAmount"))     ? 0  : rd.GetDecimal(rd.GetOrdinal("TotalAmount")),
                    TotalCollected  = rd.IsDBNull(rd.GetOrdinal("TotalCollected"))  ? 0  : rd.GetDecimal(rd.GetOrdinal("TotalCollected")),
                    TotalDue        = rd.IsDBNull(rd.GetOrdinal("TotalDue"))        ? 0  : rd.GetDecimal(rd.GetOrdinal("TotalDue")),
                    TotalPartners   = rd.IsDBNull(rd.GetOrdinal("TotalPartners"))   ? 0  : rd.GetInt32(rd.GetOrdinal("TotalPartners")),
                    TotalOwners     = rd.IsDBNull(rd.GetOrdinal("TotalOwners"))     ? 0  : rd.GetInt32(rd.GetOrdinal("TotalOwners")),
                });

            // Result set 2: sub totals
            await rd.NextResultAsync();
            if (await rd.ReadAsync())
                subTotal = new CampCollectionSubTotal {
                    SubTotalRooms           = rd.IsDBNull(rd.GetOrdinal("SubTotalRooms"))           ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalRooms")),
                    SubTotalOccupied        = rd.IsDBNull(rd.GetOrdinal("SubTotalOccupied"))        ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalOccupied")),
                    SubTotalVacant          = rd.IsDBNull(rd.GetOrdinal("SubTotalVacant"))          ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalVacant")),
                    SubTotalContracts       = rd.IsDBNull(rd.GetOrdinal("SubTotalContracts"))       ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalContracts")),
                    SubTotalActiveContracts = rd.IsDBNull(rd.GetOrdinal("SubTotalActiveContracts")) ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalActiveContracts")),
                    SubTotalAmount          = rd.IsDBNull(rd.GetOrdinal("SubTotalAmount"))          ? 0 : rd.GetDecimal(rd.GetOrdinal("SubTotalAmount")),
                    SubTotalCollected       = rd.IsDBNull(rd.GetOrdinal("SubTotalCollected"))       ? 0 : rd.GetDecimal(rd.GetOrdinal("SubTotalCollected")),
                    SubTotalDue             = rd.IsDBNull(rd.GetOrdinal("SubTotalDue"))             ? 0 : rd.GetDecimal(rd.GetOrdinal("SubTotalDue")),
                    SubTotalPartners        = rd.IsDBNull(rd.GetOrdinal("SubTotalPartners"))        ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalPartners")),
                    SubTotalOwners          = rd.IsDBNull(rd.GetOrdinal("SubTotalOwners"))          ? 0 : rd.GetInt32(rd.GetOrdinal("SubTotalOwners")),
                };
        }

        int totalRecords = pTotal.Value != DBNull.Value ? (int)pTotal.Value : rows.Count;
        return new CampCollectionReportResponse {
            Rows         = rows,
            SubTotal     = subTotal,
            TotalRecords = totalRecords,
        };
    }

    // ── Room Wise Collection Report ───────────────────────────────────────────
    public async Task<RoomWiseCollectionResponse> GetRoomWiseCollectionReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetRoomWiseCollectionReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@CampId",         r.CampId!.Value);
        cmd.Parameters.AddWithValue("@DateFrom",       (object?)r.DateFrom       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",         (object?)r.DateTo         ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",          (object?)r.Month          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractStatus", (object?)r.ContractStatus ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomStatus",     (object?)r.Status         ?? DBNull.Value);
        var pTotal = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pTotal);

        var rows    = new List<RoomWiseCollectionRow>();
        var summary = new RoomWiseCollectionSummary();

        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            // Result set 1: rows
            while (await rd.ReadAsync())
                rows.Add(new RoomWiseCollectionRow {
                    RoomId         = rd.IsDBNull(rd.GetOrdinal("RoomId"))         ? 0    : rd.GetInt32(rd.GetOrdinal("RoomId")),
                    RoomNo         = rd.IsDBNull(rd.GetOrdinal("RoomNo"))         ? ""   : rd.GetString(rd.GetOrdinal("RoomNo")),
                    RoomStatus     = rd.IsDBNull(rd.GetOrdinal("RoomStatus"))     ? ""   : rd.GetString(rd.GetOrdinal("RoomStatus")),
                    MonthlyPrice   = rd.IsDBNull(rd.GetOrdinal("MonthlyPrice"))   ? 0    : rd.GetDecimal(rd.GetOrdinal("MonthlyPrice")),
                    Occupied       = !rd.IsDBNull(rd.GetOrdinal("Occupied"))      && rd.GetBoolean(rd.GetOrdinal("Occupied")),
                    ContractId     = rd.IsDBNull(rd.GetOrdinal("ContractId"))     ? ""   : rd.GetString(rd.GetOrdinal("ContractId")),
                    ContractStatus = rd.IsDBNull(rd.GetOrdinal("ContractStatus")) ? ""   : rd.GetString(rd.GetOrdinal("ContractStatus")),
                    TenantName     = rd.IsDBNull(rd.GetOrdinal("TenantName"))     ? ""   : rd.GetString(rd.GetOrdinal("TenantName")),
                    TotalAmount    = rd.IsDBNull(rd.GetOrdinal("TotalAmount"))    ? 0    : rd.GetDecimal(rd.GetOrdinal("TotalAmount")),
                    Collected      = rd.IsDBNull(rd.GetOrdinal("Collected"))      ? 0    : rd.GetDecimal(rd.GetOrdinal("Collected")),
                    Due            = rd.IsDBNull(rd.GetOrdinal("Due"))            ? 0    : rd.GetDecimal(rd.GetOrdinal("Due")),
                    LastDate       = rd.IsDBNull(rd.GetOrdinal("LastDate"))       ? null : rd.GetDateTime(rd.GetOrdinal("LastDate")),
                    LastAmount     = rd.IsDBNull(rd.GetOrdinal("LastAmount"))     ? 0    : rd.GetDecimal(rd.GetOrdinal("LastAmount")),
                    Status         = rd.IsDBNull(rd.GetOrdinal("Status"))         ? ""   : rd.GetString(rd.GetOrdinal("Status")),
                });

            // Result set 2: summary
            await rd.NextResultAsync();
            if (await rd.ReadAsync())
                summary = new RoomWiseCollectionSummary {
                    TotalRooms     = rd.IsDBNull(rd.GetOrdinal("TotalRooms"))     ? 0 : rd.GetInt32(rd.GetOrdinal("TotalRooms")),
                    OccupiedRooms  = rd.IsDBNull(rd.GetOrdinal("OccupiedRooms"))  ? 0 : rd.GetInt32(rd.GetOrdinal("OccupiedRooms")),
                    VacantRooms    = rd.IsDBNull(rd.GetOrdinal("VacantRooms"))    ? 0 : rd.GetInt32(rd.GetOrdinal("VacantRooms")),
                    TotalAmount    = rd.IsDBNull(rd.GetOrdinal("TotalAmount"))    ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalAmount")),
                    TotalCollected = rd.IsDBNull(rd.GetOrdinal("TotalCollected")) ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalCollected")),
                    TotalDue       = rd.IsDBNull(rd.GetOrdinal("TotalDue"))       ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalDue")),
                };
        }

        int totalRecords = pTotal.Value != DBNull.Value ? (int)pTotal.Value : rows.Count;
        return new RoomWiseCollectionResponse {
            Rows         = rows,
            Summary      = summary,
            TotalRecords = totalRecords,
        };
    }
}
