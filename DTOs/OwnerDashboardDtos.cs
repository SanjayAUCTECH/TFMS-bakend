namespace TFMS_software_api.DTOs;

public class OwnerDashboardResponse
{
    // ── Owner Info ────────────────────────────────────────────────
    public int?   OwnerId      { get; set; }
    public string OwnerCode    { get; set; } = string.Empty;
    public string OwnerName    { get; set; } = string.Empty;
    public string OwnerContact { get; set; } = string.Empty;
    public string OwnerEmail   { get; set; } = string.Empty;
    public string OwnerStatus  { get; set; } = string.Empty;

    // ── Financial Summary (from OwnerTransactions) ────────────────
    /// <summary>SUM of DR transactions = total amount payable to owner</summary>
    public decimal TotalAmount { get; set; }

    /// <summary>SUM of CR transactions = total amount paid to owner</summary>
    public decimal TotalPaid   { get; set; }

    /// <summary>TotalAmount - TotalPaid</summary>
    public decimal TotalDue    { get; set; }

    // ── Contract Stats ────────────────────────────────────────────
    public int ActiveContracts { get; set; }
    public int TotalContracts  { get; set; }

    // ── Recent Transactions ───────────────────────────────────────
    public List<OwnerTxnItem> RecentTransactions { get; set; } = new();
}

public class OwnerTxnItem
{
    public int     Id               { get; set; }
    public string  TxnCode          { get; set; } = string.Empty;
    public int     OwnerContractId  { get; set; }
    public string  OcCode           { get; set; } = string.Empty;
    public int     OwnerId          { get; set; }
    public string  OwnerName        { get; set; } = string.Empty;
    public int     CampId           { get; set; }
    public string  CampName         { get; set; } = string.Empty;
    /// <summary>DR = Debit (contract created) | CR = Credit (payment made)</summary>
    public string  TxnType          { get; set; } = string.Empty;
    public decimal Amount           { get; set; }
    public string? TxnDate          { get; set; }
    public string  Mode             { get; set; } = string.Empty;
    public string  Description      { get; set; } = string.Empty;
    public string  InstallmentNos   { get; set; } = string.Empty;
    public int?    ExpenseId        { get; set; }
    public DateTime CreatedAt       { get; set; }
}
