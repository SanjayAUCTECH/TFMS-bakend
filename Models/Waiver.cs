namespace TFMS_software_api.Models;

public class Waiver
{
    public int      Id             { get; set; }
    public int      TenantId       { get; set; }
    public string   TenantName     { get; set; } = string.Empty;
    public string   ContractId     { get; set; } = string.Empty;
    public int      InstallmentNo  { get; set; }
    public decimal  OriginalAmount { get; set; }
    public decimal  WaiverAmount   { get; set; }
    public decimal  BalanceAmount  { get; set; }
    public string   Remark         { get; set; } = string.Empty;
    public DateTime WaiverDate     { get; set; }
    public string   CreatedBy      { get; set; } = string.Empty;
}
