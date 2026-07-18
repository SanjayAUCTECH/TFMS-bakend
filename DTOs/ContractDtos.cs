namespace TFMS_software_api.DTOs;

public class CreateContractRequest
{
    public int?          TenantId          { get; set; }
    // CampId removed — use CampIds array only
    public List<int>     CampIds           { get; set; } = new();  // all selected camps
    public DateTime?     StartDate         { get; set; }
    public int?          Months            { get; set; } = 12;
    public List<ContractRoomItem>? Rooms   { get; set; }           // rich room data with amounts
    public decimal?      SecurityDeposit   { get; set; } = 0;
    public string?       ContractType      { get; set; } = "Monthly";
    public string?       InstallmentType   { get; set; } = "monthly";
    public string?       IssuedBy          { get; set; } = string.Empty;
    public string?       Notes             { get; set; } = string.Empty;
    public decimal?      LessorAmount      { get; set; } = 0;
    public decimal?      MonthlyTotal      { get; set; }
    public decimal?      ContractTotal     { get; set; }
    public string?  ContractPropertyUsage  { get; set; } = string.Empty;
    public string?  ContractBuildingName   { get; set; } = string.Empty;
    public string?  ContractPropertyType   { get; set; } = string.Empty;
    public string?  ContractLocation       { get; set; } = string.Empty;
    public string?  ContractPropertyNo     { get; set; } = string.Empty;
    public string?  ContractPropertyArea   { get; set; } = string.Empty;
    public string?  ContractPremisesNo     { get; set; } = string.Empty;
    public string?  ContractPaymentMode    { get; set; } = string.Empty;
    public string?  ContractPlotNo         { get; set; } = string.Empty;
    public string?  ContractMakaniNo       { get; set; } = string.Empty;
}

public class ContractRoomItem
{
    public int      RoomId        { get; set; }
    public int?     CampId        { get; set; }
    public decimal? MonthlyAmount { get; set; }
    public decimal? TotalAmount   { get; set; }
}

public class UpdateContractStatusRequest
{
    public string? Status { get; set; } = string.Empty;   // Active | Expired | Terminated
}

public class UpdateContractScheduleRequest
{
    public string? ContractId { get; set; } = string.Empty;
    public List<ScheduleItemRequest>? Schedule { get; set; } = new();
}

public class UpdateContractRequest
{
    public string?   ContractId      { get; set; } = string.Empty;
    public int?      TenantId        { get; set; }
    // CampId removed — use CampIds array only
    public List<int> CampIds         { get; set; } = new();
    public DateTime? StartDate       { get; set; }
    public int?      Months          { get; set; } = 12;
    public List<int>?  RoomIds       { get; set; } = new();
    public List<ContractRoomItem>? Rooms { get; set; }
    public decimal?  SecurityDeposit { get; set; } = 0;
    public string?   ContractType    { get; set; }
    public decimal?  LessorAmount    { get; set; } = 0;
    public string?   Notes           { get; set; } = string.Empty;
    public decimal?  MonthlyTotal    { get; set; }
    public decimal?  ContractTotal   { get; set; }
    public string?  ContractPropertyUsage  { get; set; } = string.Empty;
    public string?  ContractBuildingName   { get; set; } = string.Empty;
    public string?  ContractPropertyType   { get; set; } = string.Empty;
    public string?  ContractLocation       { get; set; } = string.Empty;
    public string?  ContractPropertyNo     { get; set; } = string.Empty;
    public string?  ContractPropertyArea   { get; set; } = string.Empty;
    public string?  ContractPremisesNo     { get; set; } = string.Empty;
    public string?  ContractPaymentMode    { get; set; } = string.Empty;
    public string?  ContractPlotNo         { get; set; } = string.Empty;
    public string?  ContractMakaniNo       { get; set; } = string.Empty;
}

public class ScheduleItemRequest
{
    public int     No         { get; set; }
    public decimal Amount     { get; set; }
    public string  DueDate    { get; set; } = string.Empty;
    public string  Mode       { get; set; } = string.Empty;
    public string  Cheque     { get; set; } = string.Empty;
    public string  Clearance  { get; set; } = string.Empty;
}

public class ContractListRequest : Common.PagedRequest
{
    public int?    TenantId { get; set; }
    public int?    CampId   { get; set; }
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
}

public class ContractPaymentResponse
{
    public int      Id            { get; set; }
    public int      InstallmentNo { get; set; }
    public decimal  Amount        { get; set; }
    public DateTime DueDate       { get; set; }
    public decimal  PaidAmount    { get; set; }
    public DateTime? PaidDate     { get; set; }
    public string   Status        { get; set; } = string.Empty;
    public string   PaymentMode   { get; set; } = string.Empty;
    public string   ChequeNumber  { get; set; } = string.Empty;
    public string   ClearanceDate { get; set; } = string.Empty;
}

public class ContractResponse
{
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public int      TenantId        { get; set; }
    public string   TenantName      { get; set; } = string.Empty;
    public List<int> CampIds        { get; set; } = new();  // all associated camps
    public DateTime StartDate       { get; set; }
    public int      Months          { get; set; }
    public DateTime EndDate         { get; set; }
    public decimal  MonthlyTotal    { get; set; }
    public decimal  ContractTotal   { get; set; }
    public decimal  SecurityDeposit { get; set; }
    public string   ContractType    { get; set; } = "Monthly";   // Monthly | Scheduled
    public string   InstallmentType { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    public string   Notes           { get; set; } = string.Empty;
    public decimal  LessorAmount    { get; set; }
    public string   Status          { get; set; } = string.Empty;
    // ── Property Information ──────────────────────────────────────────────
    public string   ContractPropertyUsage  { get; set; } = string.Empty;
    public string   ContractBuildingName   { get; set; } = string.Empty;
    public string   ContractPropertyType   { get; set; } = string.Empty;
    public string   ContractLocation       { get; set; } = string.Empty;
    public string   ContractPropertyNo     { get; set; } = string.Empty;
    public string   ContractPropertyArea   { get; set; } = string.Empty;
    public string   ContractPremisesNo     { get; set; } = string.Empty;
    public string   ContractPaymentMode    { get; set; } = string.Empty;
    public string   ContractPlotNo         { get; set; } = string.Empty;
    public string   ContractMakaniNo       { get; set; } = string.Empty;
    // ─────────────────────────────────────────────────────────────────────
    public decimal  TotalPaid         { get; set; }
    public decimal  TotalDue          { get; set; }
    public decimal? LastPaymentAmount { get; set; }
    public string?  LastPaymentDate   { get; set; }
    public List<ContractRoomDetail>     Rooms    { get; set; } = new();
    public List<ContractPaymentResponse> Payments { get; set; } = new();
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class ContractRoomDetail
{
    public int      RoomId        { get; set; }
    public int      CampId        { get; set; }
    public string   RoomNo        { get; set; } = string.Empty;
    public decimal  MonthlyAmount { get; set; }
    public decimal  TotalAmount   { get; set; }
    public decimal  PaidAmount    { get; set; }
    public decimal  Balance       { get; set; }
}
