namespace TFMS_software_api.DTOs;

public class CreateCompanyRequest
{
    public string CompanyName { get; set; } = string.Empty;
    public string Status      { get; set; } = "Active";
}

public class UpdateCompanyRequest
{
    public string? CompanyName { get; set; }
    public string? Status      { get; set; }
}

public class CompanyResponse
{
    public int      Id          { get; set; }
    public string   CompanyName { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public string?  AddedBy     { get; set; }
    public string?  UpdatedBy   { get; set; }
    public string?  DeletedBy   { get; set; }
    public bool     IsDeleted   { get; set; }
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
