using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateOwnerRequest
{
    [MaxLength(200)] public string  Name    { get; set; } = string.Empty;
    [MaxLength(20)]  public string  Contact { get; set; } = string.Empty;
    [MaxLength(150)] public string? Email   { get; set; }
    public string Status { get; set; } = "Active";
}

public class UpdateOwnerRequest
{
    [MaxLength(200)] public string  Name    { get; set; } = string.Empty;
    [MaxLength(20)]  public string  Contact { get; set; } = string.Empty;
    [MaxLength(150)] public string? Email   { get; set; }
    public string Status { get; set; } = "Active";
}

public class OwnerListRequest : Common.PagedRequest { }

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
