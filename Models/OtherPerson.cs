namespace TFMS_software_api.Models;

public class OtherPerson
{
    public int      Id          { get; set; }
    public string   Code        { get; set; } = string.Empty;
    public string   Designation { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Mobile      { get; set; } = string.Empty;
    public string   Email       { get; set; } = string.Empty;
    public string   Address     { get; set; } = string.Empty;
    public string   City        { get; set; } = string.Empty;
    public string   State       { get; set; } = string.Empty;
    public string   Pincode     { get; set; } = string.Empty;
    public string   Remarks     { get; set; } = string.Empty;
    public string   Status      { get; set; } = "Active";
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
