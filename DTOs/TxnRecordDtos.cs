using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateTxnRecordRequest
{
    [Required] public string  TxnType      { get; set; } = "DR";
    [Required] public string  ContractId   { get; set; } = string.Empty;
    public string  ContractCode  { get; set; } = string.Empty;
    public int     TenantId      { get; set; }
    public int     CampId        { get; set; }
    public decimal TotalAmount   { get; set; }
    public decimal Amount        { get; set; }
    public DateTime TxnDate      { get; set; } = DateTime.UtcNow;
    public DateTime? FromDate    { get; set; }
    public DateTime? ToDate      { get; set; }
    public string  PaymentMode   { get; set; } = string.Empty;
    public int?    PaymentModeId { get; set; }
    public int?    FundPoolId    { get; set; }
    public string  FundPoolName  { get; set; } = string.Empty;
    public string  Description   { get; set; } = string.Empty;
    public string  ReceivedBy    { get; set; } = string.Empty;
    public int?    InstallmentNo { get; set; }
}

public class UpdateTxnRecordRequest
{
    public decimal  Amount        { get; set; }
    public DateTime TxnDate       { get; set; }
    public string   PaymentMode   { get; set; } = string.Empty;
    public int?     PaymentModeId { get; set; }
    public int?     FundPoolId    { get; set; }
    public string   FundPoolName  { get; set; } = string.Empty;
    public string   Description   { get; set; } = string.Empty;
    public string   ReceivedBy    { get; set; } = string.Empty;
}

public class TxnRecordResponse
{
    public int      Id                   { get; set; }
    public string   TxnId                { get; set; } = string.Empty;
    public string   TxnType              { get; set; } = string.Empty;
    public string   ContractId           { get; set; } = string.Empty;
    public string   ContractCode         { get; set; } = string.Empty;
    public int      TenantId             { get; set; }
    public string   TenantName           { get; set; } = string.Empty;
    public int      CampId               { get; set; }
    public string   CampName             { get; set; } = string.Empty;
    public decimal  TotalAmount          { get; set; }
    public decimal  Amount               { get; set; }
    public DateTime TxnDate              { get; set; }
    public DateTime? FromDate            { get; set; }
    public DateTime? ToDate              { get; set; }
    public string   PaymentMode          { get; set; } = string.Empty;
    public int?     PaymentModeId        { get; set; }
    public string   ChequeNumber         { get; set; } = string.Empty;
    public int?     FundPoolId           { get; set; }
    public string   FundPoolName         { get; set; } = string.Empty;
    public string   Description          { get; set; } = string.Empty;
    public string   ReceivedBy           { get; set; } = string.Empty;
    public string   ReceivedContact      { get; set; } = string.Empty;
    public string   IssuedBy             { get; set; } = string.Empty;
    public int?     InstallmentNo        { get; set; }
    public string   AppliedInstallments  { get; set; } = string.Empty;
    public decimal  Unallocated          { get; set; }
    public DateTime CreatedAt            { get; set; }
    public DateTime UpdatedAt            { get; set; }
}

public class TxnRecordListRequest
{
    public int?    PageNumber  { get; set; }
    public int?    PageSize    { get; set; }
    public string? ContractId  { get; set; }
    public int?    TenantId    { get; set; }
    public int?    CampId      { get; set; }
    public string? TxnType     { get; set; }
    public int ResolvedPage     => PageNumber is > 0 ? PageNumber.Value : 1;
    public int ResolvedPageSize => (PageSize is > 0) ? PageSize.Value : 500;
}
