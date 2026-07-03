namespace TFMS_software_api.Models;

public class Role
{
    public int      Id        { get; set; }
    public string   RoleCode  { get; set; } = string.Empty;
    public string   RoleName  { get; set; } = string.Empty;
    public string   Status    { get; set; } = "Active";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
