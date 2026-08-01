namespace TFMS_software_api.Models;

public class Owner
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string?  Contact   { get; set; }
    public string?  Email     { get; set; }
    public string   Status    { get; set; } = "Active";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    // Audit
    public int?  AddedBy   { get; set; }
    public int?  UpdatedBy { get; set; }
    public bool  IsDeleted { get; set; }
}
