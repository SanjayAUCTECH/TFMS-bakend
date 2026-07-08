namespace TFMS_software_api.Models;

public class TxnRecord
{
    public int      Id             { get; set; }
    public string   TxnId          { get; set; } = string.Empty;
    public string   TxnType        { get; set; } = "DR";   // DR | CR
    public string   ContractId     { get; set; } = string.Empty;
    public string   ContractCode   { get; set; } = string.Empty;
    public int      TenantId       { get; set; }
    public int      CampId         { get; set; }
    public decimal  TotalAmount    { get; set; }
    public decimal  Amount         { get; set; }
    public DateTime TxnDate        { get; set; }
    public DateTime? FromDate      { get; set; }
    public DateTime? ToDate        { get; set; }
    public string   PaymentMode    { get; set; } = string.Empty;
    public int?     PaymentModeId  { get; set; }
    public int?     FundPoolId     { get; set; }
    public string   FundPoolName   { get; set; } = string.Empty;
    public string   Description    { get; set; } = string.Empty;
    public string   ReceivedBy     { get; set; } = string.Empty;
    public int?     InstallmentNo  { get; set; }
    public DateTime CreatedAt      { get; set; }
    public DateTime UpdatedAt      { get; set; }
    // Joined fields
    public string   TenantName     { get; set; } = string.Empty;
    public string   CampName       { get; set; } = string.Empty;
}
