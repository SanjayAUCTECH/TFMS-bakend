namespace TFMS_software_api.DTOs;

public class CreateCompanyAssetRequest
{
    public string? AssetType    { get; set; }
    public string? DocumentName { get; set; }
    public string? CompanyName  { get; set; }
    public string? IssueDate    { get; set; }
    public string? ExpiryDate   { get; set; }
    public string  Status       { get; set; } = "Active";
    public string? DocumentUrl  { get; set; }
    public string? Remarks      { get; set; }
    // File — set by controller after Cloudinary upload
    public Microsoft.AspNetCore.Http.IFormFile? Document { get; set; }
}

public class UpdateCompanyAssetRequest
{
    public string? AssetType    { get; set; }
    public string? DocumentName { get; set; }
    public string? CompanyName  { get; set; }
    public string? IssueDate    { get; set; }
    public string? ExpiryDate   { get; set; }
    public string  Status       { get; set; } = "Active";
    public string? DocumentUrl  { get; set; }
    public string? Remarks      { get; set; }
    public Microsoft.AspNetCore.Http.IFormFile? Document { get; set; }
}

public class CompanyAssetResponse
{
    public int     Id           { get; set; }
    public string  AssetCode    { get; set; } = string.Empty;
    public string  AssetType    { get; set; } = string.Empty;
    public string  DocumentName { get; set; } = string.Empty;
    public string  CompanyName  { get; set; } = string.Empty;
    public string? IssueDate    { get; set; }
    public string? ExpiryDate   { get; set; }
    public string  Status       { get; set; } = string.Empty;
    public string? DocumentUrl  { get; set; }
    public string  Remarks      { get; set; } = string.Empty;
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}

public class CompanyAssetListRequest : Common.PagedRequest { }
