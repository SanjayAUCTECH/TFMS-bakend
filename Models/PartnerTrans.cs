namespace TFMS_software_api.Models;

public class PartnerTrans
{
    public int      Id          { get; set; }
    public int      PartnerId   { get; set; }
    public string   PaymentMode { get; set; } = string.Empty;
    public string   Type        { get; set; } = string.Empty;  // "Income" | "Expense"
    public string   AccountHead { get; set; } = string.Empty;
    public decimal  Amount      { get; set; }
    public string?  AccountId   { get; set; }
    public string   Remark      { get; set; } = string.Empty;
    public int?     AddedBy     { get; set; }
    public int?     UpdatedBy   { get; set; }
    public int?     IsDeletedBy { get; set; }
    public bool     IsDeleted   { get; set; }
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
