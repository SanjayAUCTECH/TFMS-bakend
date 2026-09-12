namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────
public class PartnerPayoutReportRequest
{
    public int? Month      { get; set; }   // 1..12
    public int? Year       { get; set; }   // e.g. 2026
    public int? PartnerId  { get; set; }   // filter by partner
    public int? PageNumber { get; set; }
    public int? PageSize   { get; set; }

    public int ResolvedPageNumber => PageNumber is > 0 ? PageNumber.Value : 1;
    public int ResolvedPageSize   => PageSize   is > 0 ? PageSize.Value   : 1000;
}

// ── Per Partner Row ───────────────────────────────────────────
public class PartnerPayoutReportRow
{
    public int     PartnerId            { get; set; }
    public string  PartnerCode          { get; set; } = string.Empty;
    public string  PartnerName          { get; set; } = string.Empty;
    public string  Mobile               { get; set; } = string.Empty;
    public string  Email                { get; set; } = string.Empty;
    public string  Status               { get; set; } = string.Empty;

    /// <summary>
    /// Pichle mahino ka baqaaya (Payout Before - Expense Before)
    /// </summary>
    public decimal ClosingBalance       { get; set; }

    /// <summary>
    /// Selected month mein generate hua payout (PartnerMonthlyPayout)
    /// </summary>
    public decimal PayoutGenerated      { get; set; }

    /// <summary>
    /// ClosingBalance + PayoutGenerated
    /// </summary>
    public decimal TotalRemainingPayout { get; set; }

    /// <summary>
    /// Selected month mein jo paisa diya gaya (Expense type)
    /// </summary>
    public decimal PaidAmount           { get; set; }

    /// <summary>
    /// TotalRemainingPayout - PaidAmount
    /// </summary>
    public decimal Balance              { get; set; }
}

// ── Summary ───────────────────────────────────────────────────
public class PartnerPayoutReportSummary
{
    public int     TotalPartners           { get; set; }
    public decimal TotalClosingBalance     { get; set; }
    public decimal TotalPayoutGenerated    { get; set; }
    public decimal TotalRemainingPayout    { get; set; }
    public decimal TotalPaidAmount         { get; set; }
    public decimal TotalBalance            { get; set; }
    public string? ReportMonth             { get; set; }  // e.g. "July 2026"
}

// ── Full Response ─────────────────────────────────────────────
public class PartnerPayoutReportResponse
{
    public PartnerPayoutReportSummary    Summary      { get; set; } = new();
    public List<PartnerPayoutReportRow>  Rows         { get; set; } = new();
    public int                           TotalRecords { get; set; }
}
