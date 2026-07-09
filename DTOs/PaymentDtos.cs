using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class RecordPaymentRequest
{
    [Required] public string  ContractId      { get; set; } = string.Empty;
    // InstallmentNo = 0 means auto-distribute across pending installments
    public int     InstallmentNo   { get; set; } = 0;
    [Range(0.01, double.MaxValue)] public decimal PaidAmount { get; set; }
    [Required] public DateTime PaidDate        { get; set; }
    public int?    PaymentModeId   { get; set; }
    public string  PaymentMode     { get; set; } = string.Empty;
    public string  ChequeNumber    { get; set; } = string.Empty;
    public string  ClearanceDate   { get; set; } = string.Empty;
    public string  Description     { get; set; } = string.Empty;
    public string  ReceivedBy      { get; set; } = string.Empty;
    public string  ReceivedContact { get; set; } = string.Empty;
    public int?    FundPoolId      { get; set; }
    public string  FundPoolName    { get; set; } = string.Empty;
    public string  IssuedBy        { get; set; } = string.Empty;
}

public class PaymentListRequest : Common.PagedRequest
{
    public string? ContractId    { get; set; }
    public int?    TenantId      { get; set; }
    public int?    CampId        { get; set; }
    public string? Month         { get; set; }   // e.g. "June"
    public string? Year          { get; set; }   // e.g. "2026"
    public string? PaymentStatus { get; set; }   // Pending|Paid|Partial|Overdue
    public int?    PaymentModeId { get; set; }
    public string? DateFrom      { get; set; }
    public string? DateTo        { get; set; }
}

public class PaymentResponse
{
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public string   TenantName      { get; set; } = string.Empty;
    public string   TenantCode      { get; set; } = string.Empty;
    public string   RoomNo          { get; set; } = string.Empty;
    public string   CampName        { get; set; } = string.Empty;
    public string   FloorName       { get; set; } = string.Empty;
    public int      InstallmentNo   { get; set; }
    public decimal  Amount          { get; set; }
    public DateTime DueDate         { get; set; }
    public decimal  PaidAmount      { get; set; }
    public decimal  BalanceAmount   { get; set; }
    public DateTime? PaidDate       { get; set; }
    public string   Status          { get; set; } = string.Empty;
    public string   PaymentMode     { get; set; } = string.Empty;
    public int?     PaymentModeId   { get; set; }
    public string   ChequeNumber    { get; set; } = string.Empty;
    public string   ClearanceDate   { get; set; } = string.Empty;
    public string   Description     { get; set; } = string.Empty;
    public string   ReceivedBy      { get; set; } = string.Empty;
    public string   ReceivedContact { get; set; } = string.Empty;
    public int?     FundPoolId      { get; set; }
    public string   FundPoolName    { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    // Derived month/year for Monthly Due view
    public string   DueMonth        { get; set; } = string.Empty;
    public int      DueYear         { get; set; }
}
