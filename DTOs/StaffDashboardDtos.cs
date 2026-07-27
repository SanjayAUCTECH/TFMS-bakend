namespace TFMS_software_api.DTOs;

public class StaffDashboardResponse
{
    // ── Staff Info ────────────────────────────────────────────────
    public int?   StaffId     { get; set; }
    public string StaffCode   { get; set; } = string.Empty;
    public string StaffName   { get; set; } = string.Empty;
    public string Role        { get; set; } = string.Empty;
    public string Designation { get; set; } = string.Empty;
    public string JobTitle    { get; set; } = string.Empty;
    public string Contact     { get; set; } = string.Empty;
    public string Email       { get; set; } = string.Empty;
    public string Status      { get; set; } = string.Empty;

    // ── Financial Summary ─────────────────────────────────────────
    /// <summary>Total amount received by staff (company expense = staff credit)</summary>
    public decimal TotalIncome       { get; set; }
    public int     TotalTransactions { get; set; }

    // ── Recent Transactions ───────────────────────────────────────
    public List<StaffTxnItem> RecentTransactions { get; set; } = new();
}

public class StaffTxnItem
{
    public int     Id            { get; set; }
    public string  TxnRefId      { get; set; } = string.Empty;
    /// <summary>Always 'Credit' — from staff perspective (company pays = staff receives)</summary>
    public string  TxnType       { get; set; } = "Credit";
    public string? Date          { get; set; }
    public decimal Amount        { get; set; }
    public string  Head          { get; set; } = string.Empty;
    public string  Mode          { get; set; } = string.Empty;
    public string  FundPoolName  { get; set; } = string.Empty;
    public string  Purpose       { get; set; } = string.Empty;
    public int     CampId        { get; set; }
    public string  CampName      { get; set; } = string.Empty;
    public int     RecipientId   { get; set; }
    public string  RecipientName { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
}
