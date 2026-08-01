namespace TFMS_software_api.DTOs;

public class CreateTenantRequest
{
    public string  Type                { get; set; } = "Individual";
    public string  Name                { get; set; } = string.Empty;
    public string? Passport            { get; set; }
    public string? Nationality         { get; set; }
    public string? EmiratesId          { get; set; }
    public string? Contact             { get; set; }
    public string? Whatsapp            { get; set; }
    public string? Email               { get; set; }
    public string? Address             { get; set; }
    public string  Status              { get; set; } = "Active";
    // Company fields
    public string? Company             { get; set; }
    public string? TradeLicense        { get; set; }
    public string? LicensingAuthority  { get; set; }
    public string? NumberOfCoOccupants { get; set; }
    // Property details
    public string? PlotNo              { get; set; }
    public string? MakaniNo            { get; set; }
    public string? PropertyArea        { get; set; }
    public string? PremisesNo          { get; set; }
    // Lessor details
    public string? LessorName          { get; set; }
    public string? LessorEid           { get; set; }
    public string? LessorLicense       { get; set; }
    public string? LessorLicAuthority  { get; set; }
    public string? LessorEmail         { get; set; }
    public string? LessorPhone         { get; set; }
}

public class UpdateTenantRequest : CreateTenantRequest { }

public class TenantListRequest : Common.PagedRequest
{
    public int?    Id     { get; set; }
    public int?    CampId { get; set; }
    public string? Type   { get; set; }
}

public class TenantResponse
{
    public int      Id                  { get; set; }
    public string   Type                { get; set; } = string.Empty;
    public string   Name                { get; set; } = string.Empty;
    public string   Passport            { get; set; } = string.Empty;
    public string   Nationality         { get; set; } = string.Empty;
    public string   EmiratesId          { get; set; } = string.Empty;
    public string   Contact             { get; set; } = string.Empty;
    public string   Whatsapp            { get; set; } = string.Empty;
    public string   Email               { get; set; } = string.Empty;
    public string   Address             { get; set; } = string.Empty;
    public string   Status              { get; set; } = string.Empty;
    public string   Company             { get; set; } = string.Empty;
    public string   TradeLicense        { get; set; } = string.Empty;
    public string   LicensingAuthority  { get; set; } = string.Empty;
    public string   NumberOfCoOccupants { get; set; } = string.Empty;
    public string   PlotNo              { get; set; } = string.Empty;
    public string   MakaniNo            { get; set; } = string.Empty;
    public string   PropertyArea        { get; set; } = string.Empty;
    public string   PremisesNo          { get; set; } = string.Empty;
    public string   LessorName          { get; set; } = string.Empty;
    public string   LessorEid           { get; set; } = string.Empty;
    public string   LessorLicense       { get; set; } = string.Empty;
    public string   LessorLicAuthority  { get; set; } = string.Empty;
    public string   LessorEmail         { get; set; } = string.Empty;
    public string   LessorPhone         { get; set; } = string.Empty;
    public DateTime CreatedAt           { get; set; }
    public DateTime UpdatedAt           { get; set; }
}
