namespace TFMS_software_api.DTOs;

public class CreateSalonMasterRequest
{
    public string? Name           { get; set; }
    public string? Address        { get; set; }
    public string? Contact        { get; set; }
    public string? Description    { get; set; }
    public string? ThumbnailImage { get; set; }
    public string? Status         { get; set; } = "Active";
}

public class UpdateSalonMasterRequest
{
    public string? Name           { get; set; }
    public string? Address        { get; set; }
    public string? Contact        { get; set; }
    public string? Description    { get; set; }
    public string? ThumbnailImage { get; set; }
    public string? Status         { get; set; }
}

public class SalonMasterListRequest : Common.PagedRequest { }

public class SalonMasterResponse
{
    public int       Id             { get; set; }
    public string?   Name           { get; set; }
    public string?   Address        { get; set; }
    public string?   Contact        { get; set; }
    public string?   Description    { get; set; }
    public string?   ThumbnailImage { get; set; }
    public string?   Status         { get; set; }
    public DateTime  CreatedAt      { get; set; }
    public DateTime? UpdatedAt      { get; set; }
}
