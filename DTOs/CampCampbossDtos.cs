using Swashbuckle.AspNetCore.Annotations;

namespace TFMS_software_api.DTOs;

/// <summary>Campboss ko multiple camps assign karne ka request</summary>
public class AssignCampbossToCampRequest
{
    [SwaggerSchema("Campboss ID jisko camps assign karne hain")]
    public int CampbossId { get; set; }

    [SwaggerSchema("Camps list — jo bhejo woh assign honge")]
    public List<CampCampbossItem> Camps { get; set; } = new();
}

public class CampCampbossItem
{
    [SwaggerSchema("Camp ID")]
    public int CampId { get; set; }

    [SwaggerSchema("Type — 'Percentage' ya 'Fixed'")]
    public string Type { get; set; } = string.Empty;

    [SwaggerSchema("Amount — percentage value ya fixed amount")]
    public decimal Amount { get; set; } = 0;
}

/// <summary>Camp-Campboss assignment response</summary>
public class CampCampbossResponse
{
    public int      Id           { get; set; }
    public int      CampId       { get; set; }
    public string   CampName     { get; set; } = string.Empty;
    public int      CampbossId   { get; set; }
    public string   CampbossName { get; set; } = string.Empty;
    public string   CampbossCode { get; set; } = string.Empty;
    public string   Type         { get; set; } = string.Empty;
    public decimal  Amount       { get; set; }
}
