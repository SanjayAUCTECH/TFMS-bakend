namespace TFMS_software_api.Models;

public class Income
{
    public int      Id           { get; set; }
    public string   IncomeId     { get; set; } = string.Empty;
    public DateTime Date         { get; set; }
    public string   Mode         { get; set; } = string.Empty;
    public string   Head         { get; set; } = string.Empty;
    public string   FundPool     { get; set; } = string.Empty;
    public string   FundPoolName { get; set; } = string.Empty;
    public decimal  Amount       { get; set; }
    public string   Purpose      { get; set; } = string.Empty;
    public string   Source       { get; set; } = string.Empty;
    public string   SourceRef    { get; set; } = string.Empty;
    public int?     CampId       { get; set; }
    public string   CampName     { get; set; } = string.Empty;
    public int?     PartnerId    { get; set; }
    public string   PartnerName  { get; set; } = string.Empty;
    public string   ContractId   { get; set; } = string.Empty;
    public string   ContractCode { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
    public DateTime UpdatedAt    { get; set; }
}
