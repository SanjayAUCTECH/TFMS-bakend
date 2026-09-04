namespace TFMS_software_api.Models;

public class SalonMaster
{
    public int       Id             { get; set; }
    public string?   Name           { get; set; }
    public string?   Address        { get; set; }
    public string?   Contact        { get; set; }
    public string?   Description    { get; set; }
    public string?   ThumbnailImage { get; set; }
    public string?   Status         { get; set; } = "Active";
    public bool      IsDeleted      { get; set; }
    public int?      AddedBy        { get; set; }
    public int?      UpdatedBy      { get; set; }
    public DateTime  CreatedAt      { get; set; }
    public DateTime? UpdatedAt      { get; set; }
}
