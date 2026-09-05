using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────
public class SalonExpenseReportRequest : PagedRequest
{
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
    public string? Head     { get; set; }
}

// ── Detail Row ────────────────────────────────────────────
public class SalonExpenseReportRow
{
    public int       Id            { get; set; }
    public DateTime  Date          { get; set; }
    public string?   RecipientName { get; set; }
    public string?   Head          { get; set; }
    public decimal   Amount        { get; set; }
    public string?   Description   { get; set; }
    public string?   FundType      { get; set; }   // Staff name OR "Company"
    public int?      SalonId       { get; set; }
    public string?   SalonName     { get; set; }
    public string?   Status        { get; set; }
    public DateTime  CreatedAt     { get; set; }
}

// ── Cards ─────────────────────────────────────────────────
public class SalonExpenseReportCards
{
    public decimal TotalStaffFund   { get; set; }
    public decimal TotalCompanyFund { get; set; }
    public decimal GrandTotal       { get; set; }
    public int     TotalEntries     { get; set; }
}
