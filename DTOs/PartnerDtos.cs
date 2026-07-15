namespace TFMS_software_api.DTOs;

public class CreatePartnerRequest
{
    public string  Name    { get; set; } = string.Empty;
    public string  Contact { get; set; } = string.Empty;
    public string  Mobile  { get; set; } = string.Empty;
    public string? Email   { get; set; }
    public string  Status  { get; set; } = "Active";
}

public class UpdatePartnerRequest
{
    public string  Name    { get; set; } = string.Empty;
    public string  Contact { get; set; } = string.Empty;
    public string  Mobile  { get; set; } = string.Empty;
    public string? Email   { get; set; }
    public string  Status  { get; set; } = "Active";
}

public class PartnerListRequest : Common.PagedRequest { }

public class PartnerResponse
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Contact   { get; set; } = string.Empty;
    public string   Mobile    { get; set; } = string.Empty;
    public string   Email     { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
