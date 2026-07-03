namespace TFMS_software_api.Models;

public class AccountsHead
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Type      { get; set; } = string.Empty;   // Asset | Liability | Income | Expense | Capital
    public string   Status    { get; set; } = "Active";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
