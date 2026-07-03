using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateTenantRequest
{
    public string  Type                { get; set; } = "Individual";
    [Required, MaxLength(200)] public string Name { get; set; } = string.Empty;
    [MaxLength(50)]  public string Passport            { get; set; } = string.Empty;
    [MaxLength(50)]  public string Nationality         { get; set; } = string.Empty;
    [MaxLength(30)]  public string EmiratesId          { get; set; } = string.Empty;
    [MaxLength(20)]  public string Contact             { get; set; } = string.Empty;
    [MaxLength(20)]  public string Whatsapp            { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email { get; set; } = string.Empty;
    [MaxLength(500)] public string Address             { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
    // Company fields
    [MaxLength(200)] public string Company             { get; set; } = string.Empty;
    [MaxLength(100)] public string TradeLicense        { get; set; } = string.Empty;
    [MaxLength(100)] public string LicensingAuthority  { get; set; } = string.Empty;
    [MaxLength(10)]  public string NumberOfCoOccupants { get; set; } = string.Empty;
    // Property details
    [MaxLength(30)]  public string PlotNo              { get; set; } = string.Empty;
    [MaxLength(30)]  public string MakaniNo            { get; set; } = string.Empty;
    [MaxLength(20)]  public string PropertyArea        { get; set; } = string.Empty;
    [MaxLength(30)]  public string PremisesNo          { get; set; } = string.Empty;
    // Lessor details
    [MaxLength(200)] public string LessorName          { get; set; } = string.Empty;
    [MaxLength(30)]  public string LessorEid           { get; set; } = string.Empty;
    [MaxLength(100)] public string LessorLicense       { get; set; } = string.Empty;
    [MaxLength(100)] public string LessorLicAuthority  { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string LessorEmail { get; set; } = string.Empty;
    [MaxLength(20)]  public string LessorPhone         { get; set; } = string.Empty;
}

public class UpdateTenantRequest : CreateTenantRequest { }

public class TenantListRequest : Common.PagedRequest
{
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
