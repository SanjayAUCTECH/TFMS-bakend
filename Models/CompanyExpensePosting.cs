namespace TFMS_software_api.Models;

public class CompanyExpensePosting
{
    public int       Id            { get; set; }
    public DateTime  Date          { get; set; }
    public string    Type          { get; set; } = string.Empty;
    public string?   RecipientName { get; set; }
    public string?   Head          { get; set; }
    public decimal   Amount        { get; set; }
    public string    Mode          { get; set; } = "Cash";
    public int?      SalonId       { get; set; }
    public string?   SalonName     { get; set; }   // joined from SalonMaster
    public string?   Description   { get; set; }
    public string    Status        { get; set; } = "Active";
    public bool      IsDeleted     { get; set; }
    public string?   AddedBy       { get; set; }
    public int?      UpdatedBy     { get; set; }
    public DateTime  CreatedAt     { get; set; }
    public DateTime? UpdatedAt     { get; set; }
}
