namespace TFMS_software_api.DTOs;

public class RenewContractRequest
{
    public string?   OriginalContractId   { get; set; }
    public int?      TenantId             { get; set; }
    public List<int>? CampIds             { get; set; }
    public DateTime? StartDate            { get; set; }
    public int?      Months               { get; set; } = 12;
    public List<int>? RoomIds             { get; set; }
    public List<ContractRoomItem>? Rooms  { get; set; }
    public string?   ContractType         { get; set; } = "Monthly";
    public decimal?  SecurityDeposit      { get; set; } = 0;
    public string?   InstallmentType      { get; set; } = "monthly";
    public string?   IssuedBy             { get; set; }
    public string?   Notes                { get; set; }
    public decimal?  LessorAmount         { get; set; } = 0;
    public decimal?  MonthlyTotal         { get; set; }
    public decimal?  ContractTotal        { get; set; }
    public string?   RenewalType          { get; set; } = "Monthly";  // Monthly | Yearly | Custom
    public bool?     ExpireOldContract    { get; set; } = true;
    public string?   ContractPropertyUsage { get; set; }
    public string?   ContractBuildingName  { get; set; }
    public string?   ContractPropertyType  { get; set; }
    public string?   ContractLocation      { get; set; }
    public string?   ContractPropertyNo    { get; set; }
    public string?   ContractPropertyArea  { get; set; }
    public string?   ContractPremisesNo    { get; set; }
    public string?   ContractPaymentMode   { get; set; }
    public string?   ContractPlotNo        { get; set; }
    public string?   ContractMakaniNo      { get; set; }
}

public class ContractRenewalResponse
{
    public int      Id                   { get; set; }
    public string   OriginalContractId   { get; set; } = string.Empty;
    public string   NewContractId        { get; set; } = string.Empty;
    public string   RenewalType          { get; set; } = string.Empty;
    public string?  RenewalDate          { get; set; }
    public string?  NewStartDate         { get; set; }
    public string?  NewEndDate           { get; set; }
    public int      NewMonths            { get; set; }
    public decimal  NewMonthlyTotal      { get; set; }
    public decimal  NewContractTotal     { get; set; }
    public decimal  SecurityDeposit      { get; set; }
    public string?  Notes                { get; set; }
    public string?  RenewedBy            { get; set; }
    public string   Status               { get; set; } = string.Empty;
    public string?  TenantName           { get; set; }
    public DateTime CreatedAt            { get; set; }
    public DateTime UpdatedAt            { get; set; }
}
