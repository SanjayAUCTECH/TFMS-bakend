namespace TFMS_software_api.Models;

public class Company
{
    public int       Id          { get; set; }
    public string    CompanyName { get; set; } = string.Empty;
    public string    Status      { get; set; } = "Active";
    public string?   AddedBy     { get; set; }
    public string?   UpdatedBy   { get; set; }
    public string?   DeletedBy   { get; set; }
    public bool      IsDeleted   { get; set; } = false;
    public DateTime  CreatedAt   { get; set; }
    public DateTime  UpdatedAt   { get; set; }
}
