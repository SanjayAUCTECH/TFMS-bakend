namespace TFMS_software_api.DTOs;

public class CreateWaiverRequest
{
    public int?     TenantId      { get; set; }
    public string   ContractId    { get; set; } = string.Empty;
    public int?     InstallmentNo { get; set; }
    public decimal  WaiverAmount  { get; set; }
    public string   Remark        { get; set; } = string.Empty;
    public DateTime WaiverDate    { get; set; }
}

public class WaiverListRequest : Common.PagedRequest
{
    public int?    TenantId   { get; set; }
    public string? ContractId { get; set; }
    public string? DateFrom   { get; set; }
    public string? DateTo     { get; set; }
}

public class WaiverResponse
{
    public int      Id             { get; set; }
    public string   WaiverCode     { get; set; } = string.Empty;
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
