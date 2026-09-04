namespace TFMS_software_api.Models;

public class SalonHeadMaster
{
    public int       Id        { get; set; }
    public string    HeadType  { get; set; } = string.Empty;  // Income | Expense
    public string    HeadName  { get; set; } = string.Empty;
    public string    Status    { get; set; } = "Active";
    public bool      IsDeleted { get; set; }
    public int?      AddedBy   { get; set; }
    public int?      UpdatedBy { get; set; }
    public DateTime  CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
