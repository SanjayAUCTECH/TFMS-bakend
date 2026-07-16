namespace TFMS_software_api.DTOs;

// ── Tenant Payment Alert ──────────────────────────────────────────────────────

public class TenantPaymentAlertResponse
{
    public int                            TotalAlerts  { get; set; }
    public decimal                        TotalAmount  { get; set; }
    public List<TenantPaymentAlertRow>    Alerts       { get; set; } = new();
}

public class TenantPaymentAlertRow
{
    public int     TenantId            { get; set; }
    public string  TenantName          { get; set; } = string.Empty;
    public string  Contact             { get; set; } = string.Empty;
    public string  ContractCode        { get; set; } = string.Empty;
    public string  CampName            { get; set; } = string.Empty;
    public int     InstallmentId       { get; set; }
    public int     InstallmentNo       { get; set; }
    public decimal Amount              { get; set; }
    public decimal PaidAmount          { get; set; }
    public decimal BalanceAmount       { get; set; }
    public string  DueDate             { get; set; } = string.Empty;
    public int     DaysUntilDue        { get; set; }
    public string  InstallmentStatus   { get; set; } = string.Empty;
}

// ── Tenant This-Month Summary ─────────────────────────────────────────────────

public class TenantMonthSummaryResponse
{
    public string                         Month             { get; set; } = string.Empty;
    public decimal                        GrandTotalDue     { get; set; }
    public decimal                        GrandTotalPaid    { get; set; }
    public decimal                        GrandTotalPending { get; set; }
    public int                            TotalTenants      { get; set; }
    public int                            TotalInstallments { get; set; }
    public int                            OverdueCount      { get; set; }
    public List<TenantMonthSummaryRow>    Tenants           { get; set; } = new();
}

public class TenantMonthSummaryRow
{
    public int     TenantId           { get; set; }
    public string  TenantName         { get; set; } = string.Empty;
    public string  Contact            { get; set; } = string.Empty;
    public int     TotalInstallments  { get; set; }
    public decimal TotalAmountDue     { get; set; }
    public decimal TotalPaid          { get; set; }
    public decimal TotalPending       { get; set; }
    public int     PaidCount          { get; set; }
    public int     PendingCount       { get; set; }
    public int     OverdueCount       { get; set; }
    public string  CampName           { get; set; } = string.Empty;
}
