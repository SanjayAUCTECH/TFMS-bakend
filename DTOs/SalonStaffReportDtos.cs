using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────
public class SalonStaffReportRequest
{
    public int?    SalonId  { get; set; }
    public int?    StaffId  { get; set; }
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
}

// ── Salary Payment Detail ─────────────────────────────────
public class SalaryPaymentDetail
{
    public int      StaffId       { get; set; }
    public DateTime SalaryDate    { get; set; }
    public decimal  SalaryAmount  { get; set; }
    public string?  Mode          { get; set; }
    public string?  Description   { get; set; }
}

// ── Detail Row ────────────────────────────────────────────
public class SalonStaffReportRow
{
    public int       AssignId          { get; set; }
    public int       StaffId           { get; set; }
    public string?   StaffName         { get; set; }
    public decimal   Percentage        { get; set; }
    public string?   AssignStatus      { get; set; }
    public DateTime? PayoutDateFrom    { get; set; }
    public DateTime? PayoutDateTo      { get; set; }
    public decimal   TotalCollection   { get; set; }
    public decimal   TotalDCExpense    { get; set; }
    public decimal   TotalCOExpense    { get; set; }
    public decimal   StaffProfit       { get; set; }
    public decimal   CompanyRevenue    { get; set; }
    public decimal   SalaryPaid        { get; set; }
    public decimal   RemainingBalance  => StaffProfit - SalaryPaid;
    public List<SalaryPaymentDetail> SalaryPayments { get; set; } = new();
}

// ── Cards ─────────────────────────────────────────────────
public class SalonStaffReportCards
{
    public int     TotalStaff            { get; set; }
    public int     TotalSalons           { get; set; }
    public decimal TotalCollection       { get; set; }
    public decimal TotalStaffProfit      { get; set; }
    public decimal TotalSalaryPaid       { get; set; }
    public decimal TotalRemainingBalance { get; set; }
    public decimal TotalCompanyRevenue   { get; set; }
}
