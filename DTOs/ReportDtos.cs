using Microsoft.AspNetCore.Mvc.ModelBinding;
using System.Text.Json.Serialization;

namespace TFMS_software_api.DTOs;

// ── Shared report request base ─────────────────────────────────────────────
public class ReportRequest
{
    public int?    PageNumber    { get; set; }
    public int?    PageSize      { get; set; }
    public string? SearchText    { get; set; }
    public string? SortBy        { get; set; }
    public string? SortDirection { get; set; }
    public string? Status        { get; set; }
    public string? DateFrom      { get; set; }
    public string? DateTo        { get; set; }
    public int?    CampId        { get; set; }
    public int?    TenantId      { get; set; }
    public int?    PartnerId     { get; set; }
    public string? ContractId    { get; set; }
    public string? Month         { get; set; }
    public string? Year          { get; set; }

    [BindNever, JsonIgnore]
    public int ResolvedPage     => PageNumber is > 0 ? PageNumber.Value : 1;

    [BindNever, JsonIgnore]
    public int ResolvedPageSize => (PageSize is > 0) ? PageSize.Value : int.MaxValue;

    [BindNever, JsonIgnore]
    public string ResolvedDir   => SortDirection?.ToUpper() == "DESC" ? "DESC" : "ASC";
}

// ── Inventory Report ───────────────────────────────────────────────────────
public class InventoryReportRow
{
    public int     RoomId         { get; set; }
    public string  RoomNo         { get; set; } = string.Empty;
    public string  CampName       { get; set; } = string.Empty;
    public string  FloorName      { get; set; } = string.Empty;
    public string  Status         { get; set; } = string.Empty;
    public bool    Occupied       { get; set; }
    public decimal MonthlyPrice   { get; set; }
    public string  TenantName     { get; set; } = string.Empty;
    public string  ContractId     { get; set; } = string.Empty;
    public string  ContractStatus { get; set; } = string.Empty;
    public string  OtherDetails   { get; set; } = string.Empty;
}

// Summary cards for Inventory Report
public class InventorySummary
{
    public int     TotalRooms     { get; set; }
    public int     OccupiedRooms  { get; set; }
    public int     VacantRooms    { get; set; }
    public decimal OccupancyRate  { get; set; }   // percentage
}

// Per-status breakdown for Pie chart
public class InventoryStatusBreakdown
{
    public string Status { get; set; } = string.Empty;
    public int    Count  { get; set; }
}

// Per-camp breakdown for Bar chart
public class InventoryCampBreakdown
{
    public string CampName     { get; set; } = string.Empty;
    public int    TotalRooms   { get; set; }
    public int    OccupiedRooms{ get; set; }
    public int    VacantRooms  { get; set; }
}

// Full response wrapping rows + charts + cards
public class InventoryReportResponse
{
    public InventorySummary                    Summary         { get; set; } = new();
    public List<InventoryStatusBreakdown>      StatusBreakdown { get; set; } = new();
    public List<InventoryCampBreakdown>        CampBreakdown   { get; set; } = new();
    public List<InventoryReportRow>            Rows            { get; set; } = new();
    public int                                 TotalRecords    { get; set; }
}

// ── Tenant Report ──────────────────────────────────────────────────────────
public class TenantReportRow
{
    public int      TenantId               { get; set; }
    public string   TenantName             { get; set; } = string.Empty;
    public string   Contact                { get; set; } = string.Empty;
    public string   Email                  { get; set; } = string.Empty;
    public string   EmiratesId             { get; set; } = string.Empty;
    public string   Nationality            { get; set; } = string.Empty;
    public string   Status                 { get; set; } = string.Empty;
    public string   Type                   { get; set; } = string.Empty;
    public string   ContractId             { get; set; } = string.Empty;
    public string   CampName               { get; set; } = string.Empty;
    public string   RoomNo                 { get; set; } = string.Empty;
    public DateTime? ContractStart         { get; set; }
    public DateTime? ContractEnd           { get; set; }
    public string   ContractStatus         { get; set; } = string.Empty;
    
    // Security Deposit Info
    public decimal  SecurityDeposit        { get; set; }
    public string   SecurityDepositStatus  { get; set; } = string.Empty;
    public decimal  SecurityDepositPaid    { get; set; }

    // SD Settlement breakdown
    public decimal  SdRefundAmount         { get; set; }   // SD-REF — refunded to tenant
    public decimal  SdForfeitAmount        { get; set; }   // SD-FRF — forfeited (penalty/damage)
    public decimal  SdAdjustAmount         { get; set; }   // SD-ADJ — adjusted against rent
    
    // Multiple Camps Support
    public int      CampsCount             { get; set; }
    
    // Rent Amounts
    public decimal  MonthlyRent            { get; set; }
    public decimal  ContractRentTotal      { get; set; }
    public decimal  TotalAmount            { get; set; }   // ContractRentTotal + SecurityDeposit
    
    // Room Info
    public int      RoomsBooked            { get; set; }
    
    // Payment Breakdown (TxnRecords based)
    public decimal  RentPaid               { get; set; }      // TxnType='CR'
    public decimal  SecurityDepositPaidAmount { get; set; }   // TxnType='SD-CR'
    public decimal  TotalPaid              { get; set; }      // RentPaid + SecurityDepositPaidAmount
    public decimal  TotalDue               { get; set; }      // TotalAmount - TotalPaid
    public decimal  Balance                { get; set; }      // Same as TotalDue
    
    // Waiver Info
    public decimal  WaiverAmount           { get; set; }
}

// ── Partner Report ─────────────────────────────────────────────────────────
public class PartnerReportRow
{
    public int     PartnerId       { get; set; }
    public string  PartnerCode     { get; set; } = string.Empty;
    public string  PartnerName     { get; set; } = string.Empty;
    public string  Contact         { get; set; } = string.Empty;
    public string  Mobile          { get; set; } = string.Empty;
    public string  Email           { get; set; } = string.Empty;
    public string  Status          { get; set; } = string.Empty;
    public int     TotalCamps      { get; set; }
    public string  CampNames       { get; set; } = string.Empty;
    public decimal ShareValue      { get; set; }
    public string  ShareType       { get; set; } = string.Empty;
    public decimal TotalCollected  { get; set; }   // rent collected from tenants for partner's camps
    public decimal TotalPaid       { get; set; }   // expenses paid to partner (RecipientRole=Partner, RecipientId=PartnerId)
    public decimal ShareDue        { get; set; }   // TotalCollected - TotalPaid
}

// ── Camp Report ────────────────────────────────────────────────────────────
public class CampReportRow
{
    public int     CampId           { get; set; }
    public string  CampCode         { get; set; } = string.Empty;
    public string  CampName         { get; set; } = string.Empty;
    public string  Status           { get; set; } = string.Empty;
    public int     TotalRooms       { get; set; }
    public int     OccupiedRooms    { get; set; }
    public int     VacantRooms      { get; set; }
    public int     ActiveContracts  { get; set; }
    public decimal TotalMonthlyRent { get; set; }
    public decimal TotalCollected   { get; set; }
    public decimal TotalDue         { get; set; }
    public decimal CampExpense      { get; set; }
    public decimal HOAllocated      { get; set; }
    public decimal TotalExpense     { get; set; }
    public decimal Profit           { get; set; }
}

// ── Waiver Report ──────────────────────────────────────────────────────────
public class WaiverReportRow
{
    public int      WaiverId       { get; set; }
    public int      TenantId       { get; set; }
    public string   TenantName     { get; set; } = string.Empty;
    public string   ContractId     { get; set; } = string.Empty;
    public int      InstallmentNo  { get; set; }
    public decimal  OriginalAmount { get; set; }
    public decimal  WaiverAmount   { get; set; }
    public decimal  BalanceAmount  { get; set; }
    public string   Remark         { get; set; } = string.Empty;
    public DateTime WaiverDate     { get; set; }
}

// ── Tenant Ledger ──────────────────────────────────────────────────────────
public class TenantLedgerRow
{
    public int      SerialNo      { get; set; }
    public DateTime Date          { get; set; }
    public string   Description   { get; set; } = string.Empty;
    public string   Type          { get; set; } = string.Empty;   // Debit | Credit | Waiver
    public decimal  Debit         { get; set; }
    public decimal  Credit        { get; set; }
    public decimal  Balance       { get; set; }
    public string   ContractId    { get; set; } = string.Empty;
    public int      InstallmentNo { get; set; }
    public string   PaymentMode   { get; set; } = string.Empty;
    public string   Reference     { get; set; } = string.Empty;
}

public class TenantLedgerSummary
{
    public string  TenantName   { get; set; } = string.Empty;
    public string  Contact      { get; set; } = string.Empty;
    public decimal TotalDebit   { get; set; }
    public decimal TotalCredit  { get; set; }
    public decimal NetBalance   { get; set; }
    public List<TenantLedgerRow> Rows { get; set; } = new();
}

// ── Transaction Statement ─────────────────────────────────────────────────
public class TransactionRow
{
    public int      Id             { get; set; }
    public DateTime Date           { get; set; }
    public string   ContractId     { get; set; } = string.Empty;
    public string   TenantName     { get; set; } = string.Empty;
    public string   CampName       { get; set; } = string.Empty;
    public string   RoomNo         { get; set; } = string.Empty;
    public int      InstallmentNo  { get; set; }
    public decimal  Amount         { get; set; }
    public decimal  PaidAmount     { get; set; }
    public decimal  Balance        { get; set; }
    public string   PaymentMode    { get; set; } = string.Empty;
    public string   Status         { get; set; } = string.Empty;
    public string   ReceivedBy     { get; set; } = string.Empty;
    public string   FundPoolName   { get; set; } = string.Empty;
    public string   ChequeNumber   { get; set; } = string.Empty;
    // Extended fields from new SP
    public string   AccountHead    { get; set; } = string.Empty;
    public string   Particular     { get; set; } = string.Empty;
    public string   TxnType        { get; set; } = string.Empty;   // DR | CR
    public string   Source         { get; set; } = string.Empty;
}

// ── Tenant Report — Response wrapper ──────────────────────────────────────
public class TenantReportSummary
{
    public int TotalTenants    { get; set; }
    public int ActiveTenants   { get; set; }
    public int InactiveTenants { get; set; }
    public int Companies       { get; set; }
    public int Individuals     { get; set; }
}
public class TenantTypeBreakdown   { public string Type   { get; set; } = ""; public int Count { get; set; } }
public class TenantStatusBreakdown { public string Status { get; set; } = ""; public int Count { get; set; } }
public class TenantReportResponse
{
    public TenantReportSummary         Summary         { get; set; } = new();
    public List<TenantTypeBreakdown>   TypeBreakdown   { get; set; } = new();
    public List<TenantStatusBreakdown> StatusBreakdown { get; set; } = new();
    public List<TenantReportRow>       Rows            { get; set; } = new();
    public int                         TotalRecords    { get; set; }
}

// ── Partner Report — Response wrapper ─────────────────────────────────────
public class PartnerReportSummary
{
    public int TotalPartners    { get; set; }
    public int ActivePartners   { get; set; }
    public int InactivePartners { get; set; }
    public int AssignedToCamps  { get; set; }
}
public class PartnerCampCount { public string CampName { get; set; } = ""; public int PartnerCount { get; set; } }
public class PartnerReportResponse
{
    public PartnerReportSummary   Summary       { get; set; } = new();
    public List<PartnerCampCount> CampBreakdown { get; set; } = new();
    public List<PartnerReportRow> Rows          { get; set; } = new();
    public int                    TotalRecords  { get; set; }
}

// ── Camp Report — Response wrapper ────────────────────────────────────────
public class CampReportSummary
{
    public int TotalCamps      { get; set; }
    public int ActiveCamps     { get; set; }
    public int TotalRooms      { get; set; }
    public int AvgRoomsPerCamp { get; set; }
}
public class CampChartBar { public string CampName { get; set; } = ""; public decimal Collected { get; set; } public decimal Outstanding { get; set; } public decimal MonthlyRent { get; set; } }
public class CampReportResponse
{
    public CampReportSummary    Summary      { get; set; } = new();
    public List<CampChartBar>   ChartData    { get; set; } = new();
    public List<CampReportRow>  Rows         { get; set; } = new();
    public int                  TotalRecords { get; set; }
}

// ── Waiver Report — Response wrapper ──────────────────────────────────────
public class WaiverReportSummary
{
    public int     TotalWaivers  { get; set; }
    public decimal TotalAmount   { get; set; }
    public decimal AvgAmount     { get; set; }
    public int     UniqueTenants { get; set; }
}
public class WaiverMonthlyData { public string Month { get; set; } = ""; public decimal Amount { get; set; } }
public class WaiverTenantData  { public string TenantName { get; set; } = ""; public decimal Amount { get; set; } }
public class WaiverReportResponse
{
    public WaiverReportSummary      Summary         { get; set; } = new();
    public List<WaiverMonthlyData>  MonthlyData     { get; set; } = new();
    public List<WaiverTenantData>   TenantBreakdown { get; set; } = new();
    public List<WaiverReportRow>    Rows            { get; set; } = new();
    public int                      TotalRecords    { get; set; }
}

// ── Monthly Due Report — Response wrapper ──────────────────────────────────
public class DueReportSummary
{
    public decimal TotalDueAmount { get; set; }
    public int     TotalCount     { get; set; }
    public int     OverdueCount   { get; set; }
    public decimal AvgDueAmount   { get; set; }
}

public class DueMonthlyData  { public string Month { get; set; } = ""; public decimal Amount { get; set; } }
public class DueStatusData   { public string Status{ get; set; } = ""; public int Count  { get; set; } }

public class DueReportRow
{
    public int     Id             { get; set; }
    public string  ContractId     { get; set; } = string.Empty;
    public string  TenantName     { get; set; } = string.Empty;
    public int     TenantId       { get; set; }
    public string  CampName       { get; set; } = string.Empty;
    public string  RoomNo         { get; set; } = string.Empty;
    public int     InstallmentNo  { get; set; }
    public decimal Amount         { get; set; }
    public decimal PaidAmount     { get; set; }
    public decimal BalanceAmount  { get; set; }
    public DateTime DueDate       { get; set; }
    public string  Status         { get; set; } = string.Empty;
    public string  DueStatus      { get; set; } = string.Empty;  // Overdue | Pending
    public string  PaymentMode    { get; set; } = string.Empty;
}

public class DueReportResponse
{
    public DueReportSummary        Summary     { get; set; } = new();
    public List<DueMonthlyData>    MonthlyData { get; set; } = new();  // Bar chart
    public List<DueStatusData>     StatusData  { get; set; } = new();  // Pie chart
    public List<DueReportRow>      Rows        { get; set; } = new();
    public int                     TotalRecords{ get; set; }
}
public class TransactionReportSummary
{
    public int     TotalCount   { get; set; }
    public decimal TotalIncome  { get; set; }
    public int     PaidCount    { get; set; }
    public int     PendingCount { get; set; }
}
public class TransactionMonthlyData { public string Month { get; set; } = ""; public decimal Income { get; set; } public decimal Expenses { get; set; } }
public class TransactionReportResponse
{
    public TransactionReportSummary        Summary      { get; set; } = new();
    public List<TransactionMonthlyData>    MonthlyData  { get; set; } = new();
    public List<TransactionRow>            Rows         { get; set; } = new();
    public int                             TotalRecords { get; set; }
}
public class RoomHistoryRow
{
    public string   ContractId   { get; set; } = string.Empty;
    public string   TenantName   { get; set; } = string.Empty;
    public DateTime StartDate    { get; set; }
    public DateTime EndDate      { get; set; }
    public decimal  MonthlyRent  { get; set; }
    public string   Status       { get; set; } = string.Empty;
}

// ── Make Payment (Outgoing) ───────────────────────────────────────────────
public class MakePaymentRequest
{
    public string  PaymentType    { get; set; } = string.Empty;  // Owner | Vendor | Other
    public int?    RecipientId    { get; set; }
    public string  RecipientName  { get; set; } = string.Empty;
    public decimal Amount         { get; set; }
    public DateTime PaymentDate   { get; set; }
    public int?    PaymentModeId  { get; set; }
    public string  PaymentMode    { get; set; } = string.Empty;
    public string  Description    { get; set; } = string.Empty;
    public int?    FundPoolId     { get; set; }
    public string  Reference      { get; set; } = string.Empty;
    public int?    CampId         { get; set; }
    public string? AccountHeadId  { get; set; }
}

public class MakePaymentResponse
{
    public int     Id            { get; set; }
    public string  PaymentCode   { get; set; } = string.Empty;
    public string  PaymentType   { get; set; } = string.Empty;
    public string  RecipientName { get; set; } = string.Empty;
    public decimal Amount        { get; set; }
    public DateTime PaymentDate  { get; set; }
    public string  PaymentMode   { get; set; } = string.Empty;
    public string  Description   { get; set; } = string.Empty;
    public string  FundPoolName  { get; set; } = string.Empty;
    public string  Reference     { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
}
