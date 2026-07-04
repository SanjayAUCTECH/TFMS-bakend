using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateFloorRequest
{
    [MaxLength(100)] public string Name   { get; set; } = string.Empty;
    public int? Number { get; set; }
    public string Status { get; set; } = "Active";
}

public class UpdateFloorRequest
{
    [MaxLength(100)] public string Name   { get; set; } = string.Empty;
    public int? Number { get; set; }
    public string Status { get; set; } = "Active";
}

public class FloorListRequest : Common.PagedRequest { }

public class FloorResponse
{
    public int      Id        { get; set; }
    public string   Name      { get; set; } = string.Empty;
    public int      Number    { get; set; }
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
