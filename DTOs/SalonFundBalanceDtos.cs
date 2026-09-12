namespace TFMS_software_api.DTOs;

public class SalonFundBalanceRequest
{
    public int? SalonId { get; set; }
    public int? Month   { get; set; }   // 1..12
    public int? Year    { get; set; }   // e.g. 2026
}

public class SalonFundBalanceResponse
{
    // ── Selected Month info ────────────────────────────────────────────────
    public string? ReportMonth { get; set; }   // e.g. "August 2026"

    // ── Staff ──────────────────────────────────────────────────────────────
    public decimal StaffPreviousMonthClosing { get; set; }   // Previous months closing Staff share (net of prev expenses)
    public decimal StaffCurrentClosing       { get; set; }   // Selected month closing Staff share
    public decimal TotalStaffShare           { get; set; }   // Previous + Current
    public decimal StaffSalaryPaid           { get; set; }   // Selected month Expense Head=salary
    public decimal StaffClosingBalance       { get; set; }   // TotalStaffShare - StaffSalaryPaid

    // ── Company ────────────────────────────────────────────────────────────
    public decimal CompanyPreviousMonthClosing { get; set; } // Previous months closing Company share (net of prev expenses)
    public decimal CompanyCurrentClosing       { get; set; } // Selected month closing Company share
    public decimal TotalCompanyRevenue         { get; set; } // Previous + Current
    public decimal CompanyExpense              { get; set; } // Selected month Expense (non-salary heads)
    public decimal CompanyClosingBalance       { get; set; } // TotalCompanyRevenue - CompanyExpense
}
