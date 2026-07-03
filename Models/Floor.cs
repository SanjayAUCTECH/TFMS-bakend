namespace TFMS_software_api.Models;

public class Floor
{
    public int      Id        { get; set; }
    public string   Name      { get; set; } = string.Empty;
    public int      Number    { get; set; }
    public string   Status    { get; set; } = "Active";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
