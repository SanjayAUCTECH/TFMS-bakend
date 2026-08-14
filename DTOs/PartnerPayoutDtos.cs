namespace TFMS_software_api.DTOs;

// ── Monthly Payout Dates List ─────────────────────────────────
public class MonthlyPayoutDateItem
{
    public DateTime FromDate     { get; set; }
    public DateTime ToDate       { get; set; }
    public DateTime PayoutDate   { get; set; }
    public int      PartnerCount { get; set; }
    public DateTime CreatedAt    { get; set; }
}

// ── Last Payout Date Response ─────────────────────────────────
public class LastPayoutDateResponse
{
    public DateTime? LastPayoutDate { get; set; }
    public DateTime? LastToDate     { get; set; }
    public DateTime? LastFromDate   { get; set; }
    public DateTime? LastCreatedAt  { get; set; }
}

// ── Last Monthly Payout Date Response ────────────────────────
public class LastMonthlyPayoutDateResponse
{
    public DateTime? LastPayoutDate { get; set; }
    public DateTime? LastToDate     { get; set; }
    public DateTime? LastFromDate   { get; set; }
    public DateTime? LastCreatedAt  { get; set; }
}

// ── Preview/Fetch Request ─────────────────────────────────────
public class PartnerPayoutDataRequest
{
    public DateTime FromDate { get; set; }
    public DateTime ToDate   { get; set; }
}

// ── Delete CampPayout by ToDate only ─────────────────────────
public class DeletePartnerCampPayoutRequest
{
    public DateTime ToDate { get; set; }
}

public class DeletePartnerCampPayoutResponse
{
    public int    DeletedCount { get; set; }
    public string PeriodLabel  { get; set; } = string.Empty;
}

// ── Camp-wise row (Result Set 1) ──────────────────────────────
public class PartnerCampPayoutRow
{
    public int      CampId                 { get; set; }
    public string   CampName               { get; set; } = string.Empty;
    public decimal  CampIncome             { get; set; }
    public decimal  CampExpense            { get; set; }
    public decimal  HOExpense              { get; set; }
    public decimal  TotalExpense           { get; set; }
    public decimal  BenefitAmount          { get; set; }
    public int      CampPartnerId          { get; set; }
    public int      PartnerId              { get; set; }
    public string   PartnerName            { get; set; } = string.Empty;
    public string   ShareType              { get; set; } = string.Empty;
    public decimal  CampPartnerPercentage  { get; set; }
    public decimal  PartnerShareAmount     { get; set; }
    public decimal  TotalHOExpenseAllCamps { get; set; }
    public int      ActiveCampCount        { get; set; }
    public decimal  PartnerInvestmentIncome { get; set; }  // from Incomes (Head='Partner Investment', Source='Partner')
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

// ── Save CampPayout Request ───────────────────────────────────
public class SavePartnerMonthlyCampPayoutRequest
{
    public DateTime  FromDate { get; set; }
    public DateTime  ToDate   { get; set; }
    public DateTime? Date     { get; set; }
    public List<PartnerMonthlyCampPayoutItem> Rows { get; set; } = new();
}

public class PartnerMonthlyCampPayoutItem
{
    public int      PartnerId               { get; set; }
    public int      CampId                  { get; set; }
    public decimal  CampPartnerPercentage   { get; set; }
    public decimal  CampIncome              { get; set; }
    public decimal  CampExpense             { get; set; }
    public decimal  HOExpense               { get; set; }
    public decimal  TotalExpense            { get; set; }
    public decimal  BenefitAmount           { get; set; }
    public decimal  PartnerInvestmentIncome { get; set; }
}

// ── Save CampPayout Response ──────────────────────────────────
public class SavePartnerMonthlyCampPayoutResponse
{
    public int      SavedCount { get; set; }
    public DateTime FromDate   { get; set; }
    public DateTime ToDate     { get; set; }
}

// ── Full preview response ─────────────────────────────────────
public class PartnerPayoutDataResponse
{
    public DateTime FromDate    { get; set; }
    public DateTime ToDate      { get; set; }
    public string   PeriodLabel { get; set; } = string.Empty;
    public List<PartnerCampPayoutRow>    CampDetails { get; set; } = new();
    public List<PartnerPayoutSummaryRow> Summary     { get; set; } = new();
}

// ── Payout by month — camp row ────────────────────────────────
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
    public decimal  CampPayoutAmount      { get; set; }
}

// ── Payout by month — partner total row ──────────────────────
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
    public decimal  TotalPayoutAmount     { get; set; }
    public int      TotalCamps            { get; set; }
    public List<PartnerPayoutCampRow> Camps { get; set; } = new();
}

// ── Full payout-by-month response ────────────────────────────
public class PartnerPayoutByMonthResponse
{
    public DateTime FromDate    { get; set; }
    public DateTime ToDate      { get; set; }
    public string   PeriodLabel { get; set; } = string.Empty;
    public List<PartnerPayoutTotalRow> Partners { get; set; } = new();
}

// ── Save MonthlyPayout Request ────────────────────────────────
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

// ── Delete MonthlyPayout (by month/year) ─────────────────────
public class DeletePartnerMonthlyPayoutRequest
{
    public int  Month     { get; set; }
    public int  Year      { get; set; }
    public int? PartnerId { get; set; }
}

public class DeletePartnerMonthlyPayoutResponse
{
    public int    DeletedCount { get; set; }
    public string MonthLabel   { get; set; } = string.Empty;
}

// ── MonthlyPayout GET Response ────────────────────────────────
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

// ── ReleasePayout Request ─────────────────────────────────────
public class CreatePartnerReleasePayoutRequest
{
    public DateTime  Date                  { get; set; }
    public DateTime  ReleaseDate           { get; set; }
    public int       PartnerId             { get; set; }
    public decimal   CampPartnerPercentage { get; set; }
    public decimal   TotalCampIncome       { get; set; }
    public decimal   TotalCampExpense      { get; set; }
    public decimal   TotalHOExpense        { get; set; }
    public decimal   TotalAllExpense       { get; set; }
    public decimal   TotalBenefitAmount    { get; set; }
    public decimal   PartnerShareAmount    { get; set; }
    public decimal   ReleaseAmount         { get; set; }
    public decimal   BalanceAmount         { get; set; }
}

// ── ReleasePayout Response ────────────────────────────────────
public class PartnerReleasePayoutResponse
{
    public int      Id                    { get; set; }
    public DateTime Date                  { get; set; }
    public DateTime ReleaseDate           { get; set; }
    public int      PartnerId             { get; set; }
    public string   PartnerName           { get; set; } = string.Empty;
    public decimal  CampPartnerPercentage { get; set; }
    public decimal  TotalCampIncome       { get; set; }
    public decimal  TotalCampExpense      { get; set; }
    public decimal  TotalHOExpense        { get; set; }
    public decimal  TotalAllExpense       { get; set; }
    public decimal  TotalBenefitAmount    { get; set; }
    public decimal  PartnerShareAmount    { get; set; }
    public decimal  ReleaseAmount         { get; set; }
    public decimal  BalanceAmount         { get; set; }
    public DateTime CreatedAt             { get; set; }
}
