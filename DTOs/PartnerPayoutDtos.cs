namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────
public class PartnerPayoutDataRequest
{
    /// <summary>Month number 1..12</summary>
    public int Month { get; set; }

    /// <summary>Year e.g. 2026</summary>
    public int Year  { get; set; }
}

// ── Camp-wise row (Result Set 1) ──────────────────────────────
public class PartnerCampPayoutRow
{
    public int      CampId                { get; set; }
    public string   CampName              { get; set; } = string.Empty;

    // Financials
    public decimal  CampIncome            { get; set; }
    public decimal  CampExpense           { get; set; }
    public decimal  HOExpense             { get; set; }
    public decimal  TotalExpense          { get; set; }
    public decimal  BenefitAmount         { get; set; }

    // Partner info
    public int      CampPartnerId         { get; set; }
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public string   ShareType             { get; set; } = string.Empty;
    public decimal  CampPartnerPercentage { get; set; }
    public decimal  PartnerShareAmount    { get; set; }

    // HO expense distribution info (for transparency on frontend)
    public decimal  TotalHOExpenseAllCamps { get; set; }  // total HO for month
    public int      ActiveCampCount        { get; set; }  // divided by this many camps
}

// ── Partner summary (Result Set 2) ───────────────────────────
public class PartnerPayoutSummaryRow
{
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public decimal  TotalCampIncome       { get; set; }
    public decimal  TotalCampExpense      { get; set; }
    public decimal  TotalHOExpense        { get; set; }
    public decimal  TotalAllExpense       { get; set; }
    public decimal  TotalBenefitAmount    { get; set; }
    public decimal  PartnerShareAmount    { get; set; }
}

// ── Get List Request ──────────────────────────────────────────
public class GetPartnerMonthlyCampPayoutRequest : Common.PagedRequest
{
    public int?      PartnerId { get; set; }
    public DateTime? FromDate  { get; set; }
    public DateTime? ToDate    { get; set; }
}

// ── Single record response ────────────────────────────────────
public class PartnerMonthlyCampPayoutResponse
{
    public int      Id                    { get; set; }
    public DateTime FromDate              { get; set; }
    public DateTime ToDate                { get; set; }
    public DateTime Date                  { get; set; }
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public int      CampId                { get; set; }
    public string   CampName              { get; set; } = string.Empty;
    public decimal  CampPartnerPercentage { get; set; }
    public decimal  CampIncome            { get; set; }
    public decimal  CampExpense           { get; set; }
    public decimal  HOExpense             { get; set; }
    public decimal  TotalExpense          { get; set; }
    public decimal  BenefitAmount         { get; set; }
    public int?     AddedBy               { get; set; }
    public DateTime CreatedAt             { get; set; }
    public DateTime UpdatedAt             { get; set; }
}

// ── Save Request (POST) ───────────────────────────────────────
public class SavePartnerMonthlyCampPayoutRequest
{
    /// <summary>Period start date — e.g. 2026-06-01</summary>
    public DateTime FromDate { get; set; }

    /// <summary>Period end date — e.g. 2026-06-30</summary>
    public DateTime ToDate   { get; set; }

    /// <summary>Entry date (defaults to today if not provided)</summary>
    public DateTime? Date    { get; set; }

    /// <summary>Rows to save — one per camp per partner</summary>
    public List<PartnerMonthlyCampPayoutItem> Rows { get; set; } = new();
}

public class PartnerMonthlyCampPayoutItem
{
    public int      PartnerId             { get; set; }
    public int      CampId                { get; set; }
    public decimal  CampPartnerPercentage { get; set; }
    public decimal  CampIncome            { get; set; }
    public decimal  CampExpense           { get; set; }
    public decimal  HOExpense             { get; set; }
    public decimal  TotalExpense          { get; set; }
    public decimal  BenefitAmount         { get; set; }
}

// ── Save Response ─────────────────────────────────────────────
public class SavePartnerMonthlyCampPayoutResponse
{
    public int      SavedCount { get; set; }
    public DateTime FromDate   { get; set; }
    public DateTime ToDate     { get; set; }
}

// ── Full API response ─────────────────────────────────────────
public class PartnerPayoutDataResponse
{
    public int      Month       { get; set; }
    public int      Year        { get; set; }
    public string   MonthLabel  { get; set; } = string.Empty;  // e.g. "June 2026"

    /// <summary>Camp-wise breakdown — one row per camp per partner</summary>
    public List<PartnerCampPayoutRow>    CampDetails { get; set; } = new();

    /// <summary>Partner-level totals across all camps</summary>
    public List<PartnerPayoutSummaryRow> Summary     { get; set; } = new();
}

// ── Partner Payout By Month — camp-wise row ───────────────────
public class PartnerPayoutCampRow
{
    public int      Id                    { get; set; }
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public string   PartnerCode           { get; set; } = string.Empty;
    public int      CampId                { get; set; }
    public string   CampName              { get; set; } = string.Empty;
    public DateTime FromDate              { get; set; }
    public DateTime ToDate                { get; set; }
    public decimal  CampPartnerPercentage { get; set; }
    public decimal  CampIncome            { get; set; }
    public decimal  CampExpense           { get; set; }
    public decimal  HOExpense             { get; set; }
    public decimal  TotalExpense          { get; set; }
    public decimal  BenefitAmount         { get; set; }
    public decimal  CampPayoutAmount      { get; set; }   // +ve or -ve
}

// ── Partner Payout By Month — partner total row ───────────────
public class PartnerPayoutTotalRow
{
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public string   PartnerCode           { get; set; } = string.Empty;
    public decimal  TotalIncome           { get; set; }
    public decimal  TotalCampExpense      { get; set; }
    public decimal  TotalHOExpense        { get; set; }
    public decimal  TotalExpense          { get; set; }
    public decimal  TotalBenefitAmount    { get; set; }
    public decimal  TotalPayoutAmount     { get; set; }   // +ve or -ve
    public int      TotalCamps            { get; set; }

    /// <summary>Camp-wise breakdown for this partner</summary>
    public List<PartnerPayoutCampRow> Camps { get; set; } = new();
}

// ── Full response for GetPartnerPayoutByMonth ─────────────────
public class PartnerPayoutByMonthResponse
{
    public int      Month       { get; set; }
    public int      Year        { get; set; }
    public string   MonthLabel  { get; set; } = string.Empty;

    /// <summary>Partner-wise list — each with camp breakdown inside</summary>
    public List<PartnerPayoutTotalRow> Partners { get; set; } = new();
}

// ── PartnerMonthlyPayout Save Request ─────────────────────────
public class SavePartnerMonthlyPayoutRequest
{
    public DateTime  FromDate { get; set; }
    public DateTime  ToDate   { get; set; }
    public DateTime? Date     { get; set; }
    public List<PartnerMonthlyPayoutItem> Rows { get; set; } = new();
}

public class PartnerMonthlyPayoutItem
{
    public int     PartnerId             { get; set; }
    public decimal CampPartnerPercentage { get; set; }
    public decimal TotalCampIncome       { get; set; }
    public decimal TotalCampExpense      { get; set; }
    public decimal TotalHOExpense        { get; set; }
    public decimal TotalAllExpense       { get; set; }
    public decimal TotalBenefitAmount    { get; set; }
    public decimal PartnerShareAmount    { get; set; }
}

public class SavePartnerMonthlyPayoutResponse
{
    public int      SavedCount { get; set; }
    public DateTime FromDate   { get; set; }
    public DateTime ToDate     { get; set; }
}

// ── PartnerMonthlyPayout Delete Request ───────────────────────
public class DeletePartnerMonthlyPayoutRequest
{
    /// <summary>Month 1..12</summary>
    public int  Month     { get; set; }
    /// <summary>Year e.g. 2026</summary>
    public int  Year      { get; set; }
    /// <summary>Optional — if null, all partners for that month are deleted</summary>
    public int? PartnerId { get; set; }
}

public class DeletePartnerMonthlyPayoutResponse
{
    public int    DeletedCount { get; set; }
    public string MonthLabel   { get; set; } = string.Empty;
}

// ── PartnerMonthlyPayout GET Response ─────────────────────────
public class PartnerMonthlyPayoutResponse
{
    public int      Id                    { get; set; }
    public DateTime FromDate              { get; set; }
    public DateTime ToDate                { get; set; }
    public DateTime Date                  { get; set; }
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public string   PartnerCode           { get; set; } = string.Empty;
    public decimal  CampPartnerPercentage { get; set; }
    public decimal  TotalCampIncome       { get; set; }
    public decimal  TotalCampExpense      { get; set; }
    public decimal  TotalHOExpense        { get; set; }
    public decimal  TotalAllExpense       { get; set; }
    public decimal  TotalBenefitAmount    { get; set; }
    public decimal  PartnerShareAmount    { get; set; }
    public int?     AddedBy               { get; set; }
    public DateTime CreatedAt             { get; set; }
    public DateTime UpdatedAt             { get; set; }
}

public class GetPartnerMonthlyPayoutListResponse
{
    public int      Month       { get; set; }
    public int      Year        { get; set; }
    public string   MonthLabel  { get; set; } = string.Empty;
    public List<PartnerMonthlyPayoutResponse> Partners { get; set; } = new();
}
