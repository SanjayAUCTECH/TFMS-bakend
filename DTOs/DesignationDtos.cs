namespace TFMS_software_api.DTOs;

public class CreateDesignationRequest
{
    public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class UpdateDesignationRequest
{
    public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class DesignationListRequest : Common.PagedRequest { }

public class DesignationResponse
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
