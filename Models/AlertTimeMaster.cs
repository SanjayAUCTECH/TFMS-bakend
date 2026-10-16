namespace TFMS_software_api.Models;

public class AlertTimeMaster
{
    public int      Id         { get; set; }
    public string   AlertName  { get; set; } = string.Empty;
    public int      Days       { get; set; }
    public string   Status     { get; set; } = "Active";
    public DateTime CreatedAt  { get; set; }
    public DateTime UpdatedAt  { get; set; }
    public int?     AddedBy    { get; set; }
    public int?     UpdatedBy  { get; set; }
    public bool     IsDeleted  { get; set; }
}
