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
public class VoucherReportsController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public VoucherReportsController(IDbConnectionFactory factory) => _factory = factory;

    // ── 1. Day Book ─────────────────────────────────────────────
    [HttpGet("daybook")]
    public async Task<IActionResult> GetDayBook([FromQuery] VoucherReportFilterRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetDayBook", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@VoucherType",   (object?)req.VoucherType  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHead",   (object?)req.AccountHead  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)req.CampId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",   (object?)req.PaymentMode  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",      (object?)req.TenantId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)req.SearchText   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber",    req.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      req.ResolvedPageSize);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var rows = new List<DayBookResponse>();
        DayBookTotals? totals = null;

        await using var r = await cmd.ExecuteReaderAsync();
        // Result 1: totals
        if (await r.ReadAsync())
            totals = new DayBookTotals { TotalIncome=SafeDec(r,0), TotalExpense=SafeDec(r,1), NetAmount=SafeDec(r,2) };
        await r.NextResultAsync();
        // Result 2: rows
        while (await r.ReadAsync())
            rows.Add(new DayBookResponse {
                Date=SafeDate(r,0), VoucherNo=SafeStr(r,1), VoucherType=SafeStr(r,2),
                AccountHead=SafeStr(r,3), CampName=SafeStr(r,4), Property=SafeStr(r,5),
                TenantName=SafeStr(r,6), LandlordName=SafeStr(r,7), PaymentMode=SafeStr(r,8),
                Income=SafeDec(r,9), Expense=SafeDec(r,10), RunningBalance=SafeDec(r,11),
                Purpose=SafeStr(r,12), PartyName=SafeStr(r,13) });
        await r.CloseAsync(); // ← OUTPUT param tabhi available hota hai jab reader close ho

        int totalRecords = total.Value is int tv ? tv : 0;
        return Ok(ApiResponse<object>.Ok(new { rows, totals, pagination=PaginationHelper.Build(totalRecords,req.ResolvedPageNumber,req.ResolvedPageSize) }, "Day book retrieved."));
    }

    // ── 2. Voucher Register ─────────────────────────────────────
    [HttpGet("voucher-register")]
    public async Task<IActionResult> GetVoucherRegister([FromQuery] VoucherReportFilterRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetVoucherRegister", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@VoucherType",   (object?)req.VoucherType  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",   (object?)req.PaymentMode  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPool",      (object?)req.FundPool     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)req.SearchText   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        req.SortBy ?? "TransDate");
        cmd.Parameters.AddWithValue("@SortDir",       req.SortDir ?? "DESC");
        cmd.Parameters.AddWithValue("@PageNumber",    req.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      req.ResolvedPageSize);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var rows = new List<VoucherRegisterResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            rows.Add(new VoucherRegisterResponse {
                Id=r.GetInt32(0), VoucherNo=SafeStr(r,1), VoucherDate=SafeDate(r,2),
                VoucherType=SafeStr(r,3), PartyName=SafeStr(r,4), PaymentMode=SafeStr(r,5),
                FundPool=SafeStr(r,6), Amount=SafeDec(r,7), VoucherStatus=SafeStr(r,8),
                CreatedBy=r.IsDBNull(9)?null:r.GetInt32(9) });
        await r.CloseAsync();

        int totalRecords = total.Value is int tv ? tv : 0;
        return Ok(ApiResponse<object>.Ok(new { rows, pagination=PaginationHelper.Build(totalRecords,req.ResolvedPageNumber,req.ResolvedPageSize) }, "Voucher register retrieved."));
    }

    // ── 3. Voucher Detail ───────────────────────────────────────
    [HttpGet("voucher-detail/{voucherNo}")]
    public async Task<IActionResult> GetVoucherDetail(string voucherNo)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetVoucherDetail", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@VoucherNo", voucherNo);

        VoucherDetailResponse? detail = null;
        await using var r = await cmd.ExecuteReaderAsync();
        // Result 1: header
        if (await r.ReadAsync())
            detail = new VoucherDetailResponse { VoucherNo=SafeStr(r,0), TransDate=SafeDate(r,1),
                FundPool=SafeStr(r,2), PaymentMode=SafeStr(r,3), PartyName=SafeStr(r,4),
                PaymentType=SafeStr(r,5), Amount=SafeDec(r,6), Purpose=SafeStr(r,7) };
        if (detail == null) return NotFound(ApiResponse<object>.Fail($"VoucherNo '{voucherNo}' not found."));

        await r.NextResultAsync();
        // Result 2: lines
        while (await r.ReadAsync())
            detail.Lines.Add(new VoucherDetailLine { AccountHead=SafeStr(r,0), Description=SafeStr(r,1),
                Amount=SafeDec(r,2), LineType=SafeStr(r,3), LineId=SafeStr(r,4) });

        await r.NextResultAsync();
        // Result 3: footer
        if (await r.ReadAsync())
        { detail.TotalIncome=SafeDec(r,0); detail.TotalExpense=SafeDec(r,1);
          detail.NetAmount=detail.TotalIncome-detail.TotalExpense; }

        return Ok(ApiResponse<VoucherDetailResponse>.Ok(detail, "Voucher detail retrieved."));
    }

    // ── 4. Income Register ──────────────────────────────────────
    [HttpGet("income-register")]
    public async Task<IActionResult> GetIncomeRegister([FromQuery] VoucherReportFilterRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetIncomeRegister", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",     (object?)req.FromDate    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",       (object?)req.ToDate      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear",(object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHead",  (object?)req.AccountHead ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",       (object?)req.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",     (object?)req.TenantId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",  (object?)req.PaymentMode ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",   (object?)req.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDir",      req.SortDir ?? "DESC");
        cmd.Parameters.AddWithValue("@PageNumber",   req.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",     req.ResolvedPageSize);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        decimal totalIncome = 0;
        var rows = new List<IncomeRegisterResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync()) totalIncome = SafeDec(r, 0);
        await r.NextResultAsync();
        while (await r.ReadAsync())
            rows.Add(new IncomeRegisterResponse { Date=SafeDate(r,0), IncomeId=SafeStr(r,1),
                VoucherNo=SafeStr(r,2), Camp=SafeStr(r,3), Property=SafeStr(r,4), Tenant=SafeStr(r,5),
                PartyName=SafeStr(r,6), AccountHead=SafeStr(r,7), PaymentMode=SafeStr(r,8),
                Amount=SafeDec(r,9), Purpose=SafeStr(r,10), Source=SafeStr(r,11) });
        await r.CloseAsync();

        int tot = total.Value is int tv ? tv : 0;
        return Ok(ApiResponse<object>.Ok(new { rows, totalIncome, pagination=PaginationHelper.Build(tot,req.ResolvedPageNumber,req.ResolvedPageSize) }, "Income register retrieved."));
    }

    // ── 5. Expense Register ─────────────────────────────────────
    [HttpGet("expense-register")]
    public async Task<IActionResult> GetExpenseRegister([FromQuery] VoucherReportFilterRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetExpenseRegister", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHead",   (object?)req.AccountHead ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)req.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientRole", (object?)req.RecipientRole ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",   (object?)req.PaymentMode ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)req.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDir",       req.SortDir ?? "DESC");
        cmd.Parameters.AddWithValue("@PageNumber",    req.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      req.ResolvedPageSize);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        decimal totalExpense = 0;
        var rows = new List<ExpenseRegisterResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync()) totalExpense = SafeDec(r, 0);
        await r.NextResultAsync();
        while (await r.ReadAsync())
            rows.Add(new ExpenseRegisterResponse { Date=SafeDate(r,0), ExpenseId=SafeStr(r,1),
                VoucherNo=SafeStr(r,2), Camp=SafeStr(r,3), Property=SafeStr(r,4), Recipient=SafeStr(r,5),
                AccountHead=SafeStr(r,6), PaymentMode=SafeStr(r,7), Amount=SafeDec(r,8),
                Purpose=SafeStr(r,9), RecipientRole=SafeStr(r,10) });
        await r.CloseAsync();

        int tot = total.Value is int tv ? tv : 0;
        return Ok(ApiResponse<object>.Ok(new { rows, totalExpense, pagination=PaginationHelper.Build(tot,req.ResolvedPageNumber,req.ResolvedPageSize) }, "Expense register retrieved."));
    }

    // ── 6. Account Head Ledger ──────────────────────────────────
    [HttpGet("account-head-ledger")]
    public async Task<IActionResult> GetAccountHeadLedger([FromQuery] VoucherReportFilterRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetAccountHeadLedger", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@AccountHead",   (object?)req.AccountHead   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)req.SearchText    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber",    req.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      req.ResolvedPageSize);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        AccountHeadLedgerTotals? totals = null;
        var rows = new List<AccountHeadLedgerResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync()) totals = new AccountHeadLedgerTotals { TotalCredit=SafeDec(r,0), TotalDebit=SafeDec(r,1), ClosingBalance=SafeDec(r,2) };
        await r.NextResultAsync();
        while (await r.ReadAsync())
            rows.Add(new AccountHeadLedgerResponse { TransDate=SafeDate(r,0), VoucherNo=SafeStr(r,1),
                Income=SafeDec(r,2), Expense=SafeDec(r,3), RunningBalance=SafeDec(r,4), Narration=SafeStr(r,5),
                AccountHead=SafeStr(r,6) });
        await r.CloseAsync();

        int tot = total.Value is int tv ? tv : 0;
        return Ok(ApiResponse<object>.Ok(new { rows, totals, pagination=PaginationHelper.Build(tot,req.ResolvedPageNumber,req.ResolvedPageSize) }, "Account head ledger retrieved."));
    }

    // ── 7. Camp Wise ────────────────────────────────────────────
    [HttpGet("camp-wise")]
    public async Task<IActionResult> GetCampWise([FromQuery] VoucherReportFilterRequest req, [FromQuery] bool detail = false)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampWiseReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)req.CampId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Detail",        detail ? 1 : 0);

        if (!detail)
        {
            var rows = new List<CampWiseSummary>();
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                rows.Add(new CampWiseSummary {
                    CampId             = r.GetInt32(0),
                    CampName           = SafeStr(r, 1),
                    TotalIncome        = SafeDec(r, 2),
                    TotalExpense       = SafeDec(r, 3),
                    HOExpense          = SafeDec(r, 4),
                    TotalExpenseWithHO = SafeDec(r, 5),
                    NetProfit          = SafeDec(r, 6)
                });
            // Read grand total (result set 2)
            object? grandTotal = null;
            if (await r.NextResultAsync() && await r.ReadAsync())
                grandTotal = new {
                    GrandIncome    = SafeDec(r, 0),
                    GrandExpense   = SafeDec(r, 1),
                    GrandHOExpense = SafeDec(r, 2),
                    GrandNet       = SafeDec(r, 3)
                };
            return Ok(ApiResponse<object>.Ok(new { rows, grandTotal }, "Camp wise report retrieved."));
        }
        else
        {
            var rows = new List<VoucherExpandRow>();
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                rows.Add(new VoucherExpandRow { TransDate=SafeDate(r,0), VoucherNo=SafeStr(r,1),
                    VoucherType=SafeStr(r,2), AccountHead=SafeStr(r,3), Amount=SafeDec(r,4), Purpose=SafeStr(r,5) });
            return Ok(ApiResponse<object>.Ok(new { rows }, "Camp detail retrieved."));
        }
    }

    // ── 8. Property Wise ────────────────────────────────────────
    [HttpGet("property-wise")]
    public async Task<IActionResult> GetPropertyWise([FromQuery] VoucherReportFilterRequest req, [FromQuery] bool detail = false)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPropertyWiseReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPool",      (object?)req.FundPool     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Detail",        detail ? 1 : 0);

        if (!detail)
        {
            var rows = new List<PropertyWiseSummary>();
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                rows.Add(new PropertyWiseSummary { Property=SafeStr(r,0), TotalIncome=SafeDec(r,1), TotalExpense=SafeDec(r,2), NetAmount=SafeDec(r,3) });
            return Ok(ApiResponse<object>.Ok(new { rows }, "Property wise report retrieved."));
        }
        else
        {
            var rows = new List<VoucherExpandRow>();
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                rows.Add(new VoucherExpandRow { TransDate=SafeDate(r,0), VoucherNo=SafeStr(r,1),
                    VoucherType=SafeStr(r,2), AccountHead=SafeStr(r,3), Amount=SafeDec(r,4), Purpose=SafeStr(r,5) });
            return Ok(ApiResponse<object>.Ok(new { rows }, "Property detail retrieved."));
        }
    }

    // ── 9. Monthly Profit Summary ───────────────────────────────
    [HttpGet("monthly-profit")]
    public async Task<IActionResult> GetMonthlyProfit([FromQuery] VoucherReportFilterRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetMonthlyProfitSummary", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)req.CampId       ?? DBNull.Value);

        var rows = new List<MonthlyProfitRow>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            rows.Add(new MonthlyProfitRow { Month=SafeStr(r,0), TotalIncome=SafeDec(r,1), TotalExpense=SafeDec(r,2), Profit=SafeDec(r,3) });
        return Ok(ApiResponse<object>.Ok(new { rows }, "Monthly profit summary retrieved."));
    }

    // ── 10. Financial Year Summary ──────────────────────────────
    [HttpGet("financial-year-summary")]
    public async Task<IActionResult> GetFinancialYearSummary()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetFinancialYearSummary", conn) { CommandType = CommandType.StoredProcedure };

        var rows = new List<FinancialYearRow>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            rows.Add(new FinancialYearRow { FinancialYear=SafeStr(r,0), TotalIncome=SafeDec(r,1),
                TotalExpense=SafeDec(r,2), NetProfit=SafeDec(r,3), ProfitPercentage=SafeDec(r,4) });
        return Ok(ApiResponse<object>.Ok(new { rows }, "Financial year summary retrieved."));
    }

    // ── 11. Payment Mode Report ─────────────────────────────────
    [HttpGet("payment-mode")]
    public async Task<IActionResult> GetPaymentMode([FromQuery] VoucherReportFilterRequest req, [FromQuery] bool detail = false)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPaymentModeReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@FromDate",      (object?)req.FromDate     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)req.ToDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FinancialYear", (object?)req.FinancialYear ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode",          (object?)req.PaymentMode  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Detail",        detail ? 1 : 0);

        if (!detail)
        {
            var rows = new List<PaymentModeSummary>();
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                rows.Add(new PaymentModeSummary { Mode=SafeStr(r,0), TotalIncome=SafeDec(r,1), TotalExpense=SafeDec(r,2), NetAmount=SafeDec(r,3) });
            return Ok(ApiResponse<object>.Ok(new { rows }, "Payment mode report retrieved."));
        }
        else
        {
            var rows = new List<VoucherExpandRow>();
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                rows.Add(new VoucherExpandRow { TransDate=SafeDate(r,0), VoucherNo=SafeStr(r,1),
                    VoucherType=SafeStr(r,2), AccountHead=SafeStr(r,3), Amount=SafeDec(r,4), Purpose=SafeStr(r,5) });
            return Ok(ApiResponse<object>.Ok(new { rows }, "Payment mode detail retrieved."));
        }
    }

    // ── Helper methods ──────────────────────────────────────────
    private static string   SafeStr (SqlDataReader r, int i) => r.IsDBNull(i) ? "" : r.GetString(i);
    private static decimal  SafeDec (SqlDataReader r, int i) => r.IsDBNull(i) ? 0m : r.GetDecimal(i);
    private static DateTime SafeDate(SqlDataReader r, int i) => r.IsDBNull(i) ? DateTime.MinValue : r.GetDateTime(i);
}
