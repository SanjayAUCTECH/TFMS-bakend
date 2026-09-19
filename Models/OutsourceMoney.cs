namespace TFMS_software_api.Models;

public class OutsourceMoney
{
    public int      Id           { get; set; }
    public DateTime Date         { get; set; }
    public string   Month        { get; set; } = string.Empty;  // Month name (e.g., "January 2026")
    public int      CampId       { get; set; }
    public string   CampName     { get; set; } = string.Empty;
    public int      FundPoolId   { get; set; }
    public string   FundPoolName { get; set; } = string.Empty;
    public decimal  Amount       { get; set; }
    public string   Mode         { get; set; } = string.Empty;  // Cash, Bank Transfer, Cheque, etc.
    public string   Purpose      { get; set; } = string.Empty;
    public string   Remarks      { get; set; } = string.Empty;
    public string   ReferenceNo  { get; set; } = string.Empty;  // Cheque number, Transaction ID, etc.
    public DateTime CreatedAt    { get; set; }
    public DateTime UpdatedAt    { get; set; }
    // Audit
    public int?     AddedBy      { get; set; }
    public int?     UpdatedBy    { get; set; }
    public bool     IsDeleted    { get; set; }
}
