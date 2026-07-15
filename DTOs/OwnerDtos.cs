namespace TFMS_software_api.DTOs;

public class CreateOwnerRequest
{
    public string  Name    { get; set; } = string.Empty;
    public string  Contact { get; set; } = string.Empty;
    public string? Email   { get; set; }
    public string  Status  { get; set; } = "Active";
}

public class UpdateOwnerRequest
{
    public string  Name    { get; set; } = string.Empty;
    public string  Contact { get; set; } = string.Empty;
    public string? Email   { get; set; }
    public string  Status  { get; set; } = "Active";
}

public class OwnerListRequest : Common.PagedRequest
{
    public int? Id { get; set; }
}

public class OwnerResponse
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Contact   { get; set; } = string.Empty;
    public string   Email     { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
