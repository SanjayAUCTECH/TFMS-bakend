namespace TFMS_software_api.DTOs;

public class CompanyAssetAlertResponse
{
    public int                          TotalAlerts  { get; set; }
    public int                          ExpiredCount { get; set; }
    public int                          ExpiringSoon { get; set; }
    public List<CompanyAssetAlertRow>   Alerts       { get; set; } = new();
}

public class CompanyAssetAlertRow
{
    public int     Id           { get; set; }
    public string  AssetCode    { get; set; } = string.Empty;
    public string  AssetType    { get; set; } = string.Empty;
    public string  DocumentName { get; set; } = string.Empty;
    public string  CompanyName  { get; set; } = string.Empty;
    public string  ExpiryDate   { get; set; } = string.Empty;
    public int     DaysRemaining { get; set; }
    public string  AlertType    { get; set; } = string.Empty; // "Expired" | "Expiring Soon"
}
