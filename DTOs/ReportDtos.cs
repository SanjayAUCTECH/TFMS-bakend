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
    public int     RoomId       { get; set; }
    public string  RoomNo       { get; set; } = string.Empty;
    public string  CampName     { get; set; } = string.Empty;
    public string  FloorName    { get; set; } = string.Empty;
    public string  Status       { get; set; } = string.Empty;
    public bool    Occupied     { get; set; }
    public decimal MonthlyPrice { get; set; }
    public string  TenantName   { get; set; } = string.Empty;
    public string  ContractId   { get; set; } = string.Empty;
    public string  ContractStatus { get; set; } = string.Empty;
    public string  OtherDetails { get; set; } = string.Empty;
}

// ── Tenant Report ──────────────────────────────────────────────────────────
public class TenantReportRow
{
    public int      TenantId      { get; set; }
    public string   TenantName    { get; set; } = string.Empty;
    public string   Contact       { get; set; } = string.Empty;
    public string   Email         { get; set; } = string.Empty;
    public string   EmiratesId    { get; set; } = string.Empty;
    public string   Nationality   { get; set; } = string.Empty;
    public string   Status        { get; set; } = string.Empty;
    public string   ContractId    { get; set; } = string.Empty;
    public string   CampName      { get; set; } = string.Empty;
    public string   RoomNo        { get; set; } = string.Empty;
    public DateTime? ContractStart { get; set; }
    public DateTime? ContractEnd   { get; set; }
    public string   ContractStatus { get; set; } = string.Empty;
    public decimal  MonthlyRent   { get; set; }
    public decimal  TotalPaid     { get; set; }
    public decimal  TotalDue      { get; set; }
    public decimal  Balance       { get; set; }
}

// ── Partner Report ─────────────────────────────────────────────────────────
public class PartnerReportRow
{
    public int     PartnerId    { get; set; }
    public string  PartnerCode  { get; set; } = string.Empty;
    public string  PartnerName  { get; set; } = string.Empty;
    public string  Contact      { get; set; } = string.Empty;
    public string  Mobile       { get; set; } = string.Empty;
    public string  Status       { get; set; } = string.Empty;
    public int     TotalCamps   { get; set; }
    public string  CampNames    { get; set; } = string.Empty;
    public decimal ShareValue   { get; set; }
    public string  ShareType    { get; set; } = string.Empty;
}

// ── Camp Report ────────────────────────────────────────────────────────────
public class CampReportRow
{
    public int     CampId         { get; set; }
    public string  CampCode       { get; set; } = string.Empty;
    public string  CampName       { get; set; } = string.Empty;
    public string  Status         { get; set; } = string.Empty;
    public int     TotalRooms     { get; set; }
    public int     OccupiedRooms  { get; set; }
    public int     VacantRooms    { get; set; }
    public int     ActiveContracts { get; set; }
    public decimal TotalMonthlyRent { get; set; }
    public decimal TotalCollected  { get; set; }
    public decimal TotalDue        { get; set; }
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
}

// ── Room History ──────────────────────────────────────────────────────────
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
