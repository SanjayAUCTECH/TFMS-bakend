namespace TFMS_software_api.Models;

public class PaymentMode
{
    public int    Id        { get; set; }
    public string Name      { get; set; } = string.Empty;
    public string Status    { get; set; } = "Active";
    // Audit
    public int?   AddedBy   { get; set; }
    public int?   UpdatedBy { get; set; }
    public bool   IsDeleted { get; set; }
}
