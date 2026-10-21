namespace TFMS_software_api.DTOs;

public class SaveFundPoolMonthlyBalanceRequest
{
    public int      ReportMonth { get; set; }
    public int      ReportYear  { get; set; }
    public DateTime? ReportDate { get; set; }
    public List<FundPoolMonthlyBalanceItem> FundPools { get; set; } = new();
}

public class FundPoolMonthlyBalanceItem
{
    public int     FundPoolId      { get; set; }
    public string  FundPoolName    { get; set; } = string.Empty;
    public decimal CurrentFundPool { get; set; }
    public decimal BufferFundPool  { get; set; }
    public decimal TotalFundPool   { get; set; }
}

public class GetFundPoolMonthlyBalanceRequest
{
    public int ReportMonth { get; set; }
    public int ReportYear  { get; set; }
}

public class DeleteFundPoolMonthlyBalanceRequest
{
    public int ReportMonth { get; set; }
    public int ReportYear  { get; set; }
}

public class FundPoolMonthlyBalanceListRequest : Common.PagedRequest
{
    public int? ReportYear { get; set; }
}

public class FundPoolMonthlyBalanceResponse
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
    public string   Status          { get; set; } = string.Empty;
    public DateTime CreatedAt       { get; set; }
    public DateTime UpdatedAt       { get; set; }
}

public class FundPoolMonthlyBalanceSummaryResponse
{
    public int      ReportMonth          { get; set; }
    public int      ReportYear           { get; set; }
    public DateTime ReportDate           { get; set; }
    public int      TotalFundPools       { get; set; }
    public decimal  TotalCurrentFundPool { get; set; }
    public decimal  TotalBufferFundPool  { get; set; }
    public decimal  NetTotal             { get; set; }
    public DateTime CreatedAt            { get; set; }
}

public class FundPoolMonthlyBalanceTotals
{
    public decimal TotalCurrentFundPool { get; set; }
    public decimal TotalBufferFundPool  { get; set; }
    public decimal NetTotal             { get; set; }
}
