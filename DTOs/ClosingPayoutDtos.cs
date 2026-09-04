namespace TFMS_software_api.DTOs;

/// <summary>Query filters — all optional</summary>
public class ClosingPayoutRequest
{
    public int?    SalonId  { get; set; }
    public string? DateFrom { get; set; }  // YYYY-MM-DD
    public string? DateTo   { get; set; }  // YYYY-MM-DD
}

/// <summary>One staff row in the payout result</summary>
public class ClosingPayoutStaffRow
{
    public int     StaffId            { get; set; }
    public string  StaffName          { get; set; } = string.Empty;
    public decimal StaffCollection    { get; set; }  // Total collection by this staff
    public decimal CollectionPercent  { get; set; }  // Staff collection / salon total * 100
    public decimal ExpenseShare       { get; set; }  // Expense distributed by collection %
    public decimal NetRevenue         { get; set; }  // StaffCollection - ExpenseShare
    public decimal StaffProfitPercent { get; set; }  // From SalonStaffAssign
    public decimal StaffProfit        { get; set; }  // NetRevenue * StaffProfitPercent / 100
    public decimal CompanyRevenue     { get; set; }  // NetRevenue - StaffProfit
}

/// <summary>Salon-level summary with staff breakdown</summary>
public class ClosingPayoutSalonRow
{
    public int     SalonId              { get; set; }
    public string  SalonName            { get; set; } = string.Empty;
    public decimal TotalSalonCollection { get; set; }
    public decimal TotalSalonExpense    { get; set; }
    public decimal TotalNetRevenue      { get; set; }
    public decimal TotalStaffProfit     { get; set; }
    public decimal TotalCompanyRevenue  { get; set; }
    public List<ClosingPayoutStaffRow> Staff { get; set; } = new();
}

/// <summary>Full response</summary>
public class ClosingPayoutResponse
{
    public List<ClosingPayoutSalonRow> Salons          { get; set; } = new();
    public decimal GrandTotalCollection { get; set; }
    public decimal GrandTotalExpense    { get; set; }
    public decimal GrandNetRevenue      { get; set; }
    public decimal GrandStaffProfit     { get; set; }
    public decimal GrandCompanyRevenue  { get; set; }
    public string? DateFrom             { get; set; }
    public string? DateTo               { get; set; }
}
