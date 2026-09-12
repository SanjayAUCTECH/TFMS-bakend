namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────
public class SalonStaffPayoutBalanceRequest
{
    public int? Month      { get; set; }   // 1..12
    public int? Year       { get; set; }   // e.g. 2026
    public int? StaffId    { get; set; }   // optional filter
    public int? SalonId    { get; set; }   // optional filter
    public int? PageNumber { get; set; }
    public int? PageSize   { get; set; }

    public int ResolvedPageNumber => PageNumber is > 0 ? PageNumber.Value : 1;
    public int ResolvedPageSize   => PageSize   is > 0 ? PageSize.Value   : 1000;
}

// ── Per Staff Row ─────────────────────────────────────────────
public class SalonStaffPayoutBalanceRow
{
    public int    StaffId        { get; set; }
    public string StaffCode      { get; set; } = string.Empty;
    public string StaffName      { get; set; } = string.Empty;
    public string StaffRole      { get; set; } = string.Empty;
    public string Contact        { get; set; } = string.Empty;
    public string Status         { get; set; } = string.Empty;

    /// <summary>Previous months payout - previous months salary paid</summary>
    public decimal ClosingBalance  { get; set; }

    /// <summary>Selected month ka StaffProfit (all salons merged)</summary>
    public decimal PayoutGenerated { get; set; }

    /// <summary>ClosingBalance + PayoutGenerated</summary>
    public decimal PayableAmount   { get; set; }

    /// <summary>Selected month mein salary paid (all salons merged)</summary>
    public decimal Paid            { get; set; }

    /// <summary>PayableAmount - Paid</summary>
    public decimal FinalBalance    { get; set; }
}

// ── Summary ───────────────────────────────────────────────────
public class SalonStaffPayoutBalanceSummary
{
    public int     TotalStaff            { get; set; }
    public decimal TotalClosingBalance   { get; set; }
    public decimal TotalPayoutGenerated  { get; set; }
    public decimal TotalPayableAmount    { get; set; }
    public decimal TotalPaid             { get; set; }
    public decimal TotalFinalBalance     { get; set; }
    public string? ReportMonth           { get; set; }   // e.g. "August 2026"
}

// ── Full Response ─────────────────────────────────────────────
public class SalonStaffPayoutBalanceResponse
{
    public SalonStaffPayoutBalanceSummary    Summary      { get; set; } = new();
    public List<SalonStaffPayoutBalanceRow>  Rows         { get; set; } = new();
    public int                               TotalRecords { get; set; }
}
