namespace TFMS_software_api.DTOs;

/// <summary>Tenant Dashboard — summary + recent transactions</summary>
public class TenantDashboardResponse
{
    // ── Tenant Info ──────────────────────────────────────────────
    public int?    TenantId      { get; set; }
    public string  TenantName    { get; set; } = string.Empty;
    public string  TenantContact { get; set; } = string.Empty;
    public string  TenantEmail   { get; set; } = string.Empty;
    public string  TenantStatus  { get; set; } = string.Empty;

    // ── Rent Summary ──────────────────────────────────────────────
    /// <summary>SUM of DR transactions = total rent payable</summary>
    public decimal TotalAmount  { get; set; }

    /// <summary>SUM of CR transactions = total rent paid</summary>
    public decimal TotalPaid    { get; set; }

    /// <summary>TotalAmount - TotalPaid</summary>
    public decimal TotalDue     { get; set; }

    // ── Security Deposit ─────────────────────────────────────────
    /// <summary>SUM of Contracts.SecurityDeposit</summary>
    public decimal TotalSecurityAmount  { get; set; }

    /// <summary>SUM of SD-CR transactions = security paid</summary>
    public decimal SecurityPaidAmount   { get; set; }

    /// <summary>TotalSecurityAmount - SecurityPaidAmount</summary>
    public decimal SecurityDueAmount    { get; set; }

    // ── Cancellation ──────────────────────────────────────────────
    /// <summary>SUM of ContractCancellations.PenaltyAmount</summary>
    public decimal PenaltyAmount { get; set; }

    /// <summary>SUM of ContractCancellations.RefundAmount</summary>
    public decimal RefundAmount  { get; set; }

    // ── Recent Transactions ───────────────────────────────────────
    public List<TenantTxnItem> RecentTransactions { get; set; } = new();
}

public class TenantTxnItem
{
    public int     Id                  { get; set; }
    public string  TxnId               { get; set; } = string.Empty;
    public string  TxnType             { get; set; } = string.Empty;
    public string  ContractId          { get; set; } = string.Empty;
    public string  ContractCode        { get; set; } = string.Empty;
    public int     TenantId            { get; set; }
    public string  TenantName          { get; set; } = string.Empty;
    public int     CampId              { get; set; }
    public string  CampName            { get; set; } = string.Empty;
    public decimal TotalAmount         { get; set; }
    public decimal Amount              { get; set; }
    public string? TxnDate             { get; set; }
    public string  PaymentMode         { get; set; } = string.Empty;
    public int?    PaymentModeId       { get; set; }
    public string  ChequeNumber        { get; set; } = string.Empty;
    public string  Description         { get; set; } = string.Empty;
    public string  ReceivedBy          { get; set; } = string.Empty;
    public string  FundPoolName        { get; set; } = string.Empty;
    public string  AppliedInstallments { get; set; } = string.Empty;
    public int?    InstallmentNo       { get; set; }
    public decimal Unallocated         { get; set; }
    public DateTime CreatedAt          { get; set; }
}
