namespace TFMS_software_api.DTOs;

public class OtherPersonDashboardResponse
{
    // ── OtherPerson Info ──────────────────────────────────────────
    public int?   PersonId    { get; set; }
    public string PersonCode  { get; set; } = string.Empty;
    public string PersonName  { get; set; } = string.Empty;
    public string Designation { get; set; } = string.Empty;
    public string Mobile      { get; set; } = string.Empty;
    public string Email       { get; set; } = string.Empty;
    public string Address     { get; set; } = string.Empty;
    public string Status      { get; set; } = string.Empty;

    // ── Financial Summary ─────────────────────────────────────────
    /// <summary>Total amount received (company expense = OtherPerson credit)</summary>
    public decimal TotalIncome       { get; set; }
    public int     TotalTransactions { get; set; }

    // ── Recent Transactions ───────────────────────────────────────
    public List<OtherPersonTxnItem> RecentTransactions { get; set; } = new();
}

public class OtherPersonTxnItem
{
    public int     Id            { get; set; }
    public string  TxnRefId      { get; set; } = string.Empty;
    /// <summary>Always 'Credit' — company pays = OtherPerson receives</summary>
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
