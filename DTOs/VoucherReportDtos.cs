using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── Common Filter Request ─────────────────────────────────────
public class VoucherReportFilterRequest : PagedRequest
{
    public string? FromDate       { get; set; }
    public string? ToDate         { get; set; }
    public string? FinancialYear  { get; set; }   // e.g. "2026-2027"
    public string? VoucherType    { get; set; }   // Income | Expense | null=All
    public string? AccountHead    { get; set; }
    public string? FundPool       { get; set; }
    public int?    CampId         { get; set; }
    public int?    TenantId       { get; set; }
    public string? RecipientRole  { get; set; }
    public string? PaymentMode    { get; set; }
    public string? SortBy         { get; set; } = "TransDate";
    public string? SortDir        { get; set; } = "DESC";
}

// ── 1. Day Book ───────────────────────────────────────────────
public class DayBookResponse
{
    public DateTime  Date           { get; set; }
    public string    VoucherNo      { get; set; } = "";
    public string    VoucherType    { get; set; } = "";
    public string    AccountHead    { get; set; } = "";
    public string    CampName       { get; set; } = "";
    public string    Property       { get; set; } = "";
    public string    TenantName     { get; set; } = "";
    public string    LandlordName   { get; set; } = "";
    public string    PaymentMode    { get; set; } = "";
    public decimal   Income         { get; set; }
    public decimal   Expense        { get; set; }
    public decimal   RunningBalance { get; set; }
    public string    Purpose        { get; set; } = "";
    public string    PartyName      { get; set; } = "";
}
public class DayBookTotals
{
    public decimal TotalIncome  { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal NetAmount    { get; set; }
}

// ── 2. Voucher Register ───────────────────────────────────────
public class VoucherRegisterResponse
{
    public int      Id            { get; set; }
    public string   VoucherNo     { get; set; } = "";
    public DateTime VoucherDate   { get; set; }
    public string   VoucherType   { get; set; } = "";
    public string   PartyName     { get; set; } = "";
    public string   PaymentMode   { get; set; } = "";
    public string   FundPool      { get; set; } = "";
    public decimal  Amount        { get; set; }
    public string   VoucherStatus { get; set; } = "";
    public int?     CreatedBy     { get; set; }
}

// ── 3. Voucher Detail ─────────────────────────────────────────
public class VoucherDetailResponse
{
    public string    VoucherNo   { get; set; } = "";
    public DateTime  TransDate   { get; set; }
    public string    FundPool    { get; set; } = "";
    public string    PaymentMode { get; set; } = "";
    public string    PartyName   { get; set; } = "";
    public string    PaymentType { get; set; } = "";
    public decimal   Amount      { get; set; }
    public string    Purpose     { get; set; } = "";
    public List<VoucherDetailLine> Lines { get; set; } = new();
    public decimal   TotalIncome  { get; set; }
    public decimal   TotalExpense { get; set; }
    public decimal   NetAmount    { get; set; }
}
public class VoucherDetailLine
{
    public string  AccountHead { get; set; } = "";
    public string  Description { get; set; } = "";
    public decimal Amount      { get; set; }
    public string  LineType    { get; set; } = "";
    public string  LineId      { get; set; } = "";
}

// ── 4. Income Register ────────────────────────────────────────
public class IncomeRegisterResponse
{
    public DateTime Date        { get; set; }
    public string   IncomeId    { get; set; } = "";
    public string   VoucherNo   { get; set; } = "";
    public string   Camp        { get; set; } = "";
    public string   Property    { get; set; } = "";
    public string   Tenant      { get; set; } = "";
    public string   PartyName   { get; set; } = "";
    public string   AccountHead { get; set; } = "";
    public string   PaymentMode { get; set; } = "";
    public decimal  Amount      { get; set; }
    public string   Purpose     { get; set; } = "";
    public string   Source      { get; set; } = "";
}

// ── 5. Expense Register ───────────────────────────────────────
public class ExpenseRegisterResponse
{
    public DateTime Date          { get; set; }
    public string   ExpenseId     { get; set; } = "";
    public string   VoucherNo     { get; set; } = "";
    public string   Camp          { get; set; } = "";
    public string   Property      { get; set; } = "";
    public string   Recipient     { get; set; } = "";
    public string   AccountHead   { get; set; } = "";
    public string   PaymentMode   { get; set; } = "";
    public decimal  Amount        { get; set; }
    public string   Purpose       { get; set; } = "";
    public string   RecipientRole { get; set; } = "";
}

// ── 6. Account Head Ledger ────────────────────────────────────
public class AccountHeadLedgerResponse
{
    public DateTime TransDate      { get; set; }
    public string   VoucherNo      { get; set; } = "";
    public decimal  Income         { get; set; }
    public decimal  Expense        { get; set; }
    public decimal  RunningBalance { get; set; }
    public string   Narration      { get; set; } = "";
    public string   AccountHead    { get; set; } = "";
}
public class AccountHeadLedgerTotals
{
    public decimal TotalCredit    { get; set; }
    public decimal TotalDebit     { get; set; }
    public decimal ClosingBalance { get; set; }
}

// ── 7. Camp Wise ──────────────────────────────────────────────
public class CampWiseSummary
{
    public int     CampId      { get; set; }
    public string  CampName    { get; set; } = "";
    public decimal TotalIncome  { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal NetProfit    { get; set; }
}

// ── 8. Property Wise ─────────────────────────────────────────
public class PropertyWiseSummary
{
    public string  Property     { get; set; } = "";
    public decimal TotalIncome  { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal NetAmount    { get; set; }
}

// ── 9. Monthly Profit Summary ─────────────────────────────────
public class MonthlyProfitRow
{
    public string  Month        { get; set; } = "";
    public decimal TotalIncome  { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal Profit       { get; set; }
}

// ── 10. Financial Year Summary ────────────────────────────────
public class FinancialYearRow
{
    public string  FinancialYear     { get; set; } = "";
    public decimal TotalIncome       { get; set; }
    public decimal TotalExpense      { get; set; }
    public decimal NetProfit         { get; set; }
    public decimal ProfitPercentage  { get; set; }
}

// ── 11. Payment Mode Report ───────────────────────────────────
public class PaymentModeSummary
{
    public string  Mode         { get; set; } = "";
    public decimal TotalIncome  { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal NetAmount    { get; set; }
}

// ── Detail row (shared for expand) ───────────────────────────
public class VoucherExpandRow
{
    public DateTime TransDate   { get; set; }
    public string   VoucherNo   { get; set; } = "";
    public string   VoucherType { get; set; } = "";
    public string   AccountHead { get; set; } = "";
    public decimal  Amount      { get; set; }
    public string   Purpose     { get; set; } = "";
}
