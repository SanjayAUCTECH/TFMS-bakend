namespace TFMS_software_api.Models;

public class FundPool
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Status    { get; set; } = "Active";
    public decimal  Balance   { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    // Audit
    public int?  AddedBy   { get; set; }
    public int?  UpdatedBy { get; set; }
    public bool  IsDeleted { get; set; }
}
