namespace TFMS_software_api.Models;

public class Campboss
{
    public int      Id          { get; set; }
    public string   CampbossId  { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string?  Contact     { get; set; }
    public string?  Email       { get; set; }
    public string?  Address     { get; set; }
    public string?  Username    { get; set; }
    public string?  Password    { get; set; }
    public string   LoginAccess { get; set; } = "enabled";
    public string   Status      { get; set; } = "Active";
    public string?  Remarks     { get; set; }
    public string?  EmiratesId  { get; set; }
    public string?  PassportNo  { get; set; }
    public string?  Nationality { get; set; }
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
    public int?     AddedBy     { get; set; }
    public int?     UpdatedBy   { get; set; }
    public bool     IsDeleted   { get; set; }
}
