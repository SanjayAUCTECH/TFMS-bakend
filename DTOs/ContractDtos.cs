using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateContractRequest
{
    [Range(1, int.MaxValue)]  public int           TenantId          { get; set; }
    [Range(1, int.MaxValue)]  public int           CampId            { get; set; }
    [Required]                public DateTime      StartDate         { get; set; }
    [Range(1, 120)]           public int           Months            { get; set; } = 12;
    public List<int>          RoomIds              { get; set; } = new();
    public decimal            SecurityDeposit      { get; set; } = 0;
    public string             InstallmentType      { get; set; } = "monthly";
    public string             IssuedBy             { get; set; } = string.Empty;
    public string             Notes                { get; set; } = string.Empty;
}

public class UpdateContractStatusRequest
{
    [Required] public string Status { get; set; } = string.Empty;   // Active | Expired | Terminated
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
}

public class ContractResponse
{
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public int      TenantId        { get; set; }
    public string   TenantName      { get; set; } = string.Empty;
    public int      CampId          { get; set; }
    public string   CampName        { get; set; } = string.Empty;
    public DateTime StartDate       { get; set; }
    public int      Months          { get; set; }
    public DateTime EndDate         { get; set; }
    public decimal  MonthlyTotal    { get; set; }
    public decimal  ContractTotal   { get; set; }
    public decimal  SecurityDeposit { get; set; }
    public string   InstallmentType { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    public string   Notes           { get; set; } = string.Empty;
    public string   Status          { get; set; } = string.Empty;
    public List<int>                   RoomIds  { get; set; } = new();
    public List<ContractPaymentResponse> Payments { get; set; } = new();
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
