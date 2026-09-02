namespace TFMS_software_api.Models;

public class SalonMaster
{
    public int      Id             { get; set; }
    public string   Name           { get; set; } = string.Empty;
    public string   Address        { get; set; } = string.Empty;
    public string   Contact        { get; set; } = string.Empty;
    public string?  Description    { get; set; }
    public string?  ThumbnailImage { get; set; }   // Cloudinary URL
    public string   Status         { get; set; } = "Active";
    public bool     IsDeleted      { get; set; }
    public int?     AddedBy        { get; set; }
    public int?     UpdatedBy      { get; set; }
    public DateTime CreatedAt      { get; set; }
    public DateTime? UpdatedAt     { get; set; }
}
