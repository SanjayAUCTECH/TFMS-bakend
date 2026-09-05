namespace TFMS_software_api.DTOs;

public class SalonFundBalanceRequest
{
    public int?    SalonId  { get; set; }
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
}

public class SalonFundBalanceResponse
{
    // ── Current Closing Period ─────────────────────────────────────────────
    public DateTime? CurrentClosingDateFrom { get; set; }
    public DateTime? CurrentClosingDateTo   { get; set; }

    // ── Staff ──────────────────────────────────────────────────────────────
    public decimal StaffPreviousMonthClosing { get; set; }   // Previous closings Staff share
    public decimal StaffCurrentClosing       { get; set; }   // Current closing Staff share
    public decimal TotalStaffShare           { get; set; }   // Previous + Current
    public decimal StaffSalaryPaid           { get; set; }   // Expense Head=salary paid
    public decimal StaffClosingBalance       { get; set; }   // TotalStaffShare - StaffSalaryPaid

    // ── Company ────────────────────────────────────────────────────────────
    public decimal CompanyPreviousMonthClosing { get; set; } // Previous closings Company share
    public decimal CompanyCurrentClosing       { get; set; } // Current closing Company share
    public decimal TotalCompanyRevenue         { get; set; } // Previous + Current
    public decimal CompanyExpense              { get; set; } // Expense non-salary heads
    public decimal CompanyClosingBalance       { get; set; } // TotalCompanyRevenue - CompanyExpense
}
