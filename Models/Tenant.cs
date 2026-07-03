namespace TFMS_software_api.Models;

public class Tenant
{
    public int      Id                  { get; set; }
    public string   Type                { get; set; } = "Individual";   // Individual | Company
    public string   Name                { get; set; } = string.Empty;
    public string   Passport            { get; set; } = string.Empty;
    public string   Nationality         { get; set; } = string.Empty;
    public string   EmiratesId          { get; set; } = string.Empty;
    public string   Contact             { get; set; } = string.Empty;
    public string   Whatsapp            { get; set; } = string.Empty;
    public string   Email               { get; set; } = string.Empty;
    public string   Address             { get; set; } = string.Empty;
    public string   Status              { get; set; } = "Active";
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
