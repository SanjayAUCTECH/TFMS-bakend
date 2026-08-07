namespace TFMS_software_api.Models;

public class AccountMaster
{
    public int      Id            { get; set; }
    public string   AccountId     { get; set; } = string.Empty;
    public string   VoucherNo     { get; set; } = string.Empty;
    public DateTime TransDate     { get; set; }
    public string   PaymentType   { get; set; } = string.Empty;   // Income | Expense
    public string   Mode          { get; set; } = string.Empty;
    public string   FundPool      { get; set; } = string.Empty;
    public string   FundPoolName  { get; set; } = string.Empty;
    public decimal  Amount        { get; set; }
    public string   Nature        { get; set; } = string.Empty;   // HO | Camp
    public int?     CampId        { get; set; }
    public string   CampName      { get; set; } = string.Empty;
    public string   RecipientRole { get; set; } = string.Empty;
    public string   RecipientName { get; set; } = string.Empty;
    public string   Purpose       { get; set; } = string.Empty;
    public DateTime CreatedAt     { get; set; }
    public DateTime UpdatedAt     { get; set; }
    public int?     RecipientId   { get; set; }
    // Audit
    public int?     AddedBy       { get; set; }
    public int?     UpdatedBy     { get; set; }
    public int?     DeletedBy     { get; set; }
    public bool     IsDeleted     { get; set; }
}
