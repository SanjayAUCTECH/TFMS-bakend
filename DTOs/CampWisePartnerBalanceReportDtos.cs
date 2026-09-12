namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────
public class CampWisePartnerBalanceReportRequest
{
    public int? Month      { get; set; }   // 1..12
    public int? Year       { get; set; }   // e.g. 2026
    public int? PartnerId  { get; set; }   // optional filter
    public int? CampId     { get; set; }   // optional filter
    public int? PageNumber { get; set; }
    public int? PageSize   { get; set; }

    public int ResolvedPageNumber => PageNumber is > 0 ? PageNumber.Value : 1;
    public int ResolvedPageSize   => PageSize   is > 0 ? PageSize.Value   : 1000;
}

// ── Per Camp+Partner Row ──────────────────────────────────────
public class CampWisePartnerBalanceRow
{
    public int     CampId             { get; set; }
    public string  CampCode           { get; set; } = string.Empty;
    public string  CampName           { get; set; } = string.Empty;
    public int     PartnerId          { get; set; }
    public string  PartnerCode        { get; set; } = string.Empty;
    public string  PartnerName        { get; set; } = string.Empty;

    /// <summary>Partner ka is camp mein % share</summary>
    public decimal PartnerPercentage  { get; set; }

    /// <summary>Selected month se pehle ka baqaaya (PayoutBefore - ExpenseBefore)</summary>
    public decimal ClosingBalance     { get; set; }

    /// <summary>Selected month mein generate hua payout (BenefitAmount)</summary>
    public decimal PayoutGenerated    { get; set; }

    /// <summary>ClosingBalance + PayoutGenerated</summary>
    public decimal TotalPayout        { get; set; }

    /// <summary>Selected month mein diya gaya amount (Expenses)</summary>
    public decimal Paid               { get; set; }

    /// <summary>TotalPayout - Paid</summary>
    public decimal FinalBalance       { get; set; }
}

// ── Summary ───────────────────────────────────────────────────
public class CampWisePartnerBalanceSummary
{
    public int     TotalRows             { get; set; }
    public decimal TotalClosingBalance   { get; set; }
    public decimal TotalPayoutGenerated  { get; set; }
    public decimal TotalPayout           { get; set; }
    public decimal TotalPaid             { get; set; }
    public decimal TotalFinalBalance     { get; set; }
    public string? ReportMonth           { get; set; }   // e.g. "July 2026"
}

// ── Full Response ─────────────────────────────────────────────
public class CampWisePartnerBalanceReportResponse
{
    public CampWisePartnerBalanceSummary    Summary      { get; set; } = new();
    public List<CampWisePartnerBalanceRow>  Rows         { get; set; } = new();
    public int                              TotalRecords { get; set; }
}
