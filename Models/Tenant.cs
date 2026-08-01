namespace TFMS_software_api.Models;

public class Tenant
{
    public int      Id                  { get; set; }
    public string   Type                { get; set; } = "Individual";
    public string   Name                { get; set; } = string.Empty;
    public string?  Passport            { get; set; }
    public string?  Nationality         { get; set; }
    public string?  EmiratesId          { get; set; }
    public string?  Contact             { get; set; }
    public string?  Whatsapp            { get; set; }
    public string?  Email               { get; set; }
    public string?  Address             { get; set; }
    public string   Status              { get; set; } = "Active";
    public string?  Company             { get; set; }
    public string?  TradeLicense        { get; set; }
    public string?  LicensingAuthority  { get; set; }
    public string?  NumberOfCoOccupants { get; set; }
    public string?  PlotNo              { get; set; }
    public string?  MakaniNo            { get; set; }
    public string?  PropertyArea        { get; set; }
    public string?  PremisesNo          { get; set; }
    public string?  LessorName          { get; set; }
    public string?  LessorEid           { get; set; }
    public string?  LessorLicense       { get; set; }
    public string?  LessorLicAuthority  { get; set; }
    public string?  LessorEmail         { get; set; }
    public string?  LessorPhone         { get; set; }
    public DateTime CreatedAt           { get; set; }
    public DateTime UpdatedAt           { get; set; }
    // Audit
    public int?     AddedBy             { get; set; }
    public int?     UpdatedBy           { get; set; }
    public bool     IsDeleted           { get; set; }
}
