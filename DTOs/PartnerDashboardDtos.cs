namespace TFMS_software_api.DTOs;

public class PartnerDashboardResponse
{
    // ── Partner Info ─────────────────────────────────────────────
    public int?   PartnerId      { get; set; }
    public string PartnerName    { get; set; } = string.Empty;
    public string PartnerCode    { get; set; } = string.Empty;
    public string PartnerContact { get; set; } = string.Empty;
    public string PartnerEmail   { get; set; } = string.Empty;
    public string PartnerStatus  { get; set; } = string.Empty;

    // ── Financial Summary ────────────────────────────────────────
    public decimal TotalIncome  { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal NetBalance   { get; set; }

    // ── Wallet / Payout Summary (from PartnerTrans) ──────────────
    public decimal   OpeningBalance      { get; set; }
    public decimal   ProfitGenerate      { get; set; }
    public DateTime? ProfitGenerateDate  { get; set; }
    public decimal   TotalOPAmount       { get; set; }
    public decimal   Paid                { get; set; }
    public decimal   ClosingBalance      { get; set; }
    public decimal   TotalProfit         { get; set; }
    public decimal   TotalReceived       { get; set; }
    public decimal   TotalBalance        { get; set; }

    // ── Camp / Room Stats ────────────────────────────────────────
    public int AssignedCamps  { get; set; }
    public int TotalRooms     { get; set; }
    public int OccupiedRooms  { get; set; }
    public int VacantRooms    { get; set; }

    // ── Assigned Camps Detail ────────────────────────────────────
    public List<PartnerCampItem> Camps { get; set; } = new();

    // ── Recent Transactions ──────────────────────────────────────
    public List<PartnerTxnItem> RecentTransactions { get; set; } = new();
}

public class PartnerCampItem
{
    public int     PartnerId     { get; set; }
    public int     CampId        { get; set; }
    public string  CampName      { get; set; } = string.Empty;
    public string  CampCode      { get; set; } = string.Empty;
    public string  ShareType     { get; set; } = string.Empty;
    public decimal ShareValue    { get; set; }
    public string  CampStatus    { get; set; } = string.Empty;
    public string? FromDate      { get; set; }
    public string? ToDate        { get; set; }
    public int     TotalRooms    { get; set; }
    public int     OccupiedRooms { get; set; }
    public int     VacantRooms   { get; set; }
}

public class PartnerTxnItem
{
    public string  TxnType      { get; set; } = string.Empty;  // Income | Expense
    public string  TxnRefId     { get; set; } = string.Empty;
    public string? Date         { get; set; }
    public decimal Amount       { get; set; }
    public string  Head         { get; set; } = string.Empty;
    public string  Mode         { get; set; } = string.Empty;
    public string  FundPoolName { get; set; } = string.Empty;
    public string  Purpose      { get; set; } = string.Empty;
    public int     CampId       { get; set; }
    public string  CampName     { get; set; } = string.Empty;
    public DateTime CreatedAt   { get; set; }
}
