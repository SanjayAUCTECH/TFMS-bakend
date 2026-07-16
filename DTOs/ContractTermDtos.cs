namespace TFMS_software_api.DTOs;

public class ContractTermResponse
{
    public int     Id         { get; set; }
    public string  ContractId { get; set; } = string.Empty;
    public int     PageNo     { get; set; }
    public int     TermNo     { get; set; }
    public string? TermText   { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class SaveContractTermsRequest
{
    public string? ContractId { get; set; }
    public List<ContractTermItem>? Terms { get; set; }
}

public class ContractTermItem
{
    public int     PageNo   { get; set; }
    public int     TermNo   { get; set; }
    public string? TermText { get; set; }
}
