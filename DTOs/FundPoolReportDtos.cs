namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────
public class FundPoolReportRequest
{
    public int?      FundPoolId  { get; set; }
    public string?   SearchText  { get; set; }
    public string?   Status      { get; set; }
    public int?      Month       { get; set; }   // 1..12
    public int?      Year        { get; set; }   // e.g. 2026
    public DateTime? DateFrom    { get; set; }
    public DateTime? DateTo      { get; set; }
    public int?      PageNumber  { get; set; }
    public int?      PageSize    { get; set; }

    public int ResolvedPageNumber => PageNumber is > 0 ? PageNumber.Value : 1;
    public int ResolvedPageSize   => PageSize   is > 0 ? PageSize.Value   : int.MaxValue;
}

// ── Fund Pool Summary Row ─────────────────────────────────────
public class FundPoolReportRow
{
    public int      FundPoolId             { get; set; }
    public string   FundPoolCode           { get; set; } = string.Empty;
    public string   FundPoolName           { get; set; } = string.Empty;
    public string   Status                 { get; set; } = string.Empty;
    public decimal  CurrentBalance         { get; set; }
    public decimal  TotalIncome            { get; set; }
    public decimal  TotalExpense           { get; set; }
    public decimal  TotalPaymentsReceived  { get; set; }
    public decimal  NetAmount              { get; set; }
    public decimal  BufferAmount           { get; set; }
    public decimal  BufferTotalIncome      { get; set; }
    public decimal  BufferTotalExpense     { get; set; }
    public decimal  BufferTotalAmount      { get; set; }
    public decimal  BufferNetAmount        { get; set; }
    public int      IncomeCount            { get; set; }
    public int      ExpenseCount           { get; set; }
    public int      PaymentCount           { get; set; }
    public DateTime CreatedAt              { get; set; }
    public DateTime UpdatedAt              { get; set; }
}

// ── Buffer Fund Pool Row ──────────────────────────────────────
public class FundPoolBufferRow
{
    public int     FundPoolId             { get; set; }
    public string  FundPoolCode           { get; set; } = string.Empty;
    public string  FundPoolName           { get; set; } = string.Empty;
    public string  Status                 { get; set; } = string.Empty;
    public decimal CurrentBalance         { get; set; }
    public decimal TotalIncome            { get; set; }
    public decimal TotalExpense           { get; set; }
    public decimal TotalPaymentsReceived  { get; set; }
    public decimal NetAmount              { get; set; }
    public decimal BufferTotalAmount      { get; set; }
}

// ── Transaction Row ───────────────────────────────────────────
public class FundPoolTxnRow
{
    public string   TxnType    { get; set; } = string.Empty;  // Income | Expense | Payment
    public DateTime TxnDate    { get; set; }
    public decimal  Amount     { get; set; }
    public string   Head       { get; set; } = string.Empty;
    public string   Mode       { get; set; } = string.Empty;
    public string   CampName   { get; set; } = string.Empty;
    public string   Purpose    { get; set; } = string.Empty;
    public string   VoucherNo  { get; set; } = string.Empty;
    public DateTime CreatedAt  { get; set; }
}

// ── Summary cards ─────────────────────────────────────────────
public class FundPoolReportSummary
{
    public int     TotalFundPools  { get; set; }
    public int     ActiveFundPools { get; set; }
    public decimal TotalBalance    { get; set; }
    public decimal TotalIncome     { get; set; }
    public decimal TotalExpense    { get; set; }
    public decimal TotalPayments   { get; set; }
}

// ── Full Response ─────────────────────────────────────────────
public class FundPoolReportResponse
{
    public FundPoolReportSummary       Summary      { get; set; } = new();
    public List<FundPoolReportRow>     Rows         { get; set; } = new();
    public List<FundPoolBufferRow>     BufferRows   { get; set; } = new();
    public List<FundPoolTxnRow>        Transactions { get; set; } = new();
    public int                         TotalRecords { get; set; }
}
