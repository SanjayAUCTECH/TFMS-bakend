namespace TFMS_software_api.Models;

public class FundPoolMonthlyBalance
{
    public int      Id              { get; set; }
    public int      FundPoolId      { get; set; }
    public string   FundPoolName    { get; set; } = string.Empty;
    public int      ReportMonth     { get; set; }
    public int      ReportYear      { get; set; }
    public DateTime ReportDate      { get; set; }
    public decimal  CurrentFundPool { get; set; }
    public decimal  BufferFundPool  { get; set; }
    public decimal  TotalFundPool   { get; set; }
    public string   Status          { get; set; } = "Active";
    public DateTime CreatedAt       { get; set; }
    public DateTime UpdatedAt       { get; set; }
    public int?     AddedBy         { get; set; }
    public int?     UpdatedBy       { get; set; }
    public bool     IsDeleted       { get; set; }
}
