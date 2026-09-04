using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── Save request ──────────────────────────────────────────────────────────────

public class SaveClosingPayoutItem
{
    [Required] public int     SalonId              { get; set; }
    public string?   SalonName            { get; set; }
    [Required] public int     StaffId              { get; set; }
    public string?   StaffName            { get; set; }
    public string?   DateFrom             { get; set; }
    public string?   DateTo               { get; set; }
    public decimal   StaffCollection      { get; set; }
    public decimal   TotalSalonCollection { get; set; }
    public decimal   CollectionPercent    { get; set; }
    public decimal   TotalSalonExpense    { get; set; }
    public decimal   ExpenseShare         { get; set; }
    public decimal   NetRevenue           { get; set; }
    public decimal   StaffProfitPercent   { get; set; }
    public decimal   StaffProfit          { get; set; }
    public decimal   CompanyRevenue       { get; set; }
}

public class SaveClosingPayoutRequest
{
    [Required][MinLength(1, ErrorMessage = "At least one row is required.")]
    public List<SaveClosingPayoutItem> Rows { get; set; } = new();
}

public class SaveClosingPayoutResponse
{
    public int    InsertedCount { get; set; }
    public string Message       { get; set; } = string.Empty;
}

// ── Get saved records ─────────────────────────────────────────────────────────

public class GetClosingPayoutSavedRequest : PagedRequest
{
    public int?    SalonId  { get; set; }
    public int?    StaffId  { get; set; }
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
}

public class ClosingPayoutSavedRow
{
    public int       PayoutId             { get; set; }
    public int       SalonId              { get; set; }
    public string?   SalonName            { get; set; }
    public int       StaffId              { get; set; }
    public string?   StaffName            { get; set; }
    public DateTime? DateFrom             { get; set; }
    public DateTime? DateTo               { get; set; }
    public decimal   StaffCollection      { get; set; }
    public decimal   TotalSalonCollection { get; set; }
    public decimal   CollectionPercent    { get; set; }
    public decimal   TotalSalonExpense    { get; set; }
    public decimal   ExpenseShare         { get; set; }
    public decimal   NetRevenue           { get; set; }
    public decimal   StaffProfitPercent   { get; set; }
    public decimal   StaffProfit          { get; set; }
    public decimal   CompanyRevenue       { get; set; }
    public string?   Status               { get; set; }
    public DateTime  CreatedAt            { get; set; }
    public DateTime? UpdatedAt            { get; set; }
}

/// <summary>Distinct payout date ranges saved in ClosingPayout table</summary>
public class ClosingPayoutDateRow
{
    public DateTime? DateFrom             { get; set; }
    public DateTime? DateTo               { get; set; }
    public int       SalonCount           { get; set; }
    public int       StaffCount           { get; set; }
    public int       TotalRows            { get; set; }
    public decimal   TotalCollection      { get; set; }
    public decimal   TotalStaffProfit     { get; set; }
    public decimal   TotalCompanyRevenue  { get; set; }
    public DateTime? SavedOn              { get; set; }
    /// <summary>Display label for dropdown</summary>
    public string    Label                { get; set; } = string.Empty;
}
