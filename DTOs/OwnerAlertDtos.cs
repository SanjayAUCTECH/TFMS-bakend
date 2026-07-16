namespace TFMS_software_api.DTOs;

// ── Owner Payment Alert (due within DaysAhead, not paid, not overdue) ────────

public class OwnerPaymentAlertResponse
{
    public int                           TotalAlerts  { get; set; }
    public decimal                       TotalAmount  { get; set; }
    public List<OwnerPaymentAlertRow>    Alerts       { get; set; } = new();
}

public class OwnerPaymentAlertRow
{
    public int     OwnerId         { get; set; }
    public string  OwnerCode       { get; set; } = string.Empty;
    public string  OwnerName       { get; set; } = string.Empty;
    public string  OwnerContact    { get; set; } = string.Empty;
    public int     OwnerContractId { get; set; }
    public string  ContractCode    { get; set; } = string.Empty;
    public string  CampName        { get; set; } = string.Empty;
    public int     InstallmentId   { get; set; }
    public int     InstallmentNo   { get; set; }
    public decimal Amount          { get; set; }
    public decimal PaidAmount      { get; set; }
    public decimal BalanceAmount   { get; set; }
    public string  DueDate         { get; set; } = string.Empty;  // yyyy-MM-dd
    public int     DaysUntilDue    { get; set; }                  // 0 = today, 1 = tomorrow
}

// ── Owner This-Month Summary ──────────────────────────────────────────────────

public class OwnerMonthSummaryResponse
{
    public string                        Month             { get; set; } = string.Empty; // "2026-07"
    public decimal                       GrandTotalDue     { get; set; }
    public decimal                       GrandTotalPaid    { get; set; }
    public decimal                       GrandTotalPending { get; set; }
    public int                           TotalOwners       { get; set; }
    public int                           TotalInstallments { get; set; }
    public List<OwnerMonthSummaryRow>    Owners            { get; set; } = new();
}

public class OwnerMonthSummaryRow
{
    public int     OwnerId           { get; set; }
    public string  OwnerCode         { get; set; } = string.Empty;
    public string  OwnerName         { get; set; } = string.Empty;
    public string  Contact           { get; set; } = string.Empty;
    public int     TotalInstallments { get; set; }
    public decimal TotalAmountDue    { get; set; }
    public decimal TotalPaid         { get; set; }
    public decimal TotalPending      { get; set; }
    public int     PaidCount         { get; set; }
    public int     PendingCount      { get; set; }
    public string  CampNames         { get; set; } = string.Empty;
}
