namespace TFMS_software_api.Models;

public class SDCollection
{
    public int       CollectionId { get; set; }
    public DateTime  Date         { get; set; }
    public int       SalonId      { get; set; }
    public string    SalonName    { get; set; } = string.Empty;
    public int?      StaffId      { get; set; }
    public string?   StaffName    { get; set; }
    public int?      HeadId       { get; set; }
    public string?   HeadName     { get; set; }
    public string?   Mode         { get; set; }
    public decimal?  Amount       { get; set; }
    public string?   Description  { get; set; }
    public string?   Status       { get; set; }
    public bool      IsDeleted    { get; set; }
    public int?      AddedBy      { get; set; }
    public int?      UpdatedBy    { get; set; }
    public DateTime  CreatedAt    { get; set; }
    public DateTime? UpdatedAt    { get; set; }
}
