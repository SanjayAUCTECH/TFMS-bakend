namespace TFMS_software_api.Models;

public class SalonStaffAssign
{
    public int       AssignId    { get; set; }
    public int       SalonId     { get; set; }
    public string    SalonName   { get; set; } = string.Empty;  // from JOIN
    public int       StaffId     { get; set; }
    public string    StaffName   { get; set; } = string.Empty;  // from JOIN
    public decimal   Percentage  { get; set; }
    public string?   Description { get; set; }
    public string    Status      { get; set; } = "Active";
    public bool      IsDeleted   { get; set; }
    public int?      AddedBy     { get; set; }
    public int?      UpdatedBy   { get; set; }
    public DateTime  CreatedAt   { get; set; }
    public DateTime? UpdatedAt   { get; set; }
}
