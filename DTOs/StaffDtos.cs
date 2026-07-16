using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

/// <summary>POST api/staff — all fields optional, multipart/form-data</summary>
public class CreateStaffRequest
{
    public string? Name        { get; set; }
    public string? Designation { get; set; }
    public string? Contact     { get; set; }
    public string? Email       { get; set; }
    public string? Address     { get; set; }
    public string? Username    { get; set; }
    public string? Password    { get; set; }
    public string? LoginAccess { get; set; }
    public string? Status      { get; set; }
    public string? Remarks     { get; set; }

    // Identity
    public string? EmiratesId  { get; set; }
    public string? PassportNo  { get; set; }
    public string? Nationality { get; set; }
    public string? JobTitle    { get; set; }
    public string? MoveInDate  { get; set; }
    public string? VisaExpiry  { get; set; }

    // Document dates
    public string? EmiratesIdIssueDate    { get; set; }
    public string? EmiratesIdExpiryDate   { get; set; }
    public string? PassportIssueDate      { get; set; }
    public string? PassportExpiryDate     { get; set; }
    public string? LabourCardIssueDate    { get; set; }
    public string? LabourCardExpiryDate   { get; set; }
    public string? IloeIssueDate          { get; set; }
    public string? IloeExpiryDate         { get; set; }
    public string? InsuranceIssueDate     { get; set; }
    public string? InsuranceExpiryDate    { get; set; }

    // Document files — optional
    public IFormFile? EmiratesIdDocument  { get; set; }
    public IFormFile? PassportDocument    { get; set; }
    public IFormFile? LabourCardDocument  { get; set; }
    public IFormFile? IloeDocument        { get; set; }
    public IFormFile? InsuranceDocument   { get; set; }

    // Cloudinary URLs — set by controller after upload
    public string? EmiratesIdDocumentUrl  { get; set; }
    public string? PassportDocumentUrl    { get; set; }
    public string? LabourCardDocumentUrl  { get; set; }
    public string? IloeDocumentUrl        { get; set; }
    public string? InsuranceDocumentUrl   { get; set; }
}

/// <summary>PUT api/staff/{id} — all fields optional, multipart/form-data</summary>
public class UpdateStaffRequest
{
    public string? Name        { get; set; }
    public string? Designation { get; set; }
    public string? Contact     { get; set; }
    public string? Email       { get; set; }
    public string? Address     { get; set; }
    public string? Username    { get; set; }
    public string? Password    { get; set; }
    public string? LoginAccess { get; set; }
    public string? Status      { get; set; }
    public string? Remarks     { get; set; }

    // Identity
    public string? EmiratesId  { get; set; }
    public string? PassportNo  { get; set; }
    public string? Nationality { get; set; }
    public string? JobTitle    { get; set; }
    public string? MoveInDate  { get; set; }
    public string? VisaExpiry  { get; set; }

    // Document dates
    public string? EmiratesIdIssueDate    { get; set; }
    public string? EmiratesIdExpiryDate   { get; set; }
    public string? PassportIssueDate      { get; set; }
    public string? PassportExpiryDate     { get; set; }
    public string? LabourCardIssueDate    { get; set; }
    public string? LabourCardExpiryDate   { get; set; }
    public string? IloeIssueDate          { get; set; }
    public string? IloeExpiryDate         { get; set; }
    public string? InsuranceIssueDate     { get; set; }
    public string? InsuranceExpiryDate    { get; set; }

    // Document files — optional, only when user uploads a new file
    public IFormFile? EmiratesIdDocument  { get; set; }
    public IFormFile? PassportDocument    { get; set; }
    public IFormFile? LabourCardDocument  { get; set; }
    public IFormFile? IloeDocument        { get; set; }
    public IFormFile? InsuranceDocument   { get; set; }

    // Cloudinary URLs — set by controller after upload (null = keep existing DB value)
    public string? EmiratesIdDocumentUrl  { get; set; }
    public string? PassportDocumentUrl    { get; set; }
    public string? LabourCardDocumentUrl  { get; set; }
    public string? IloeDocumentUrl        { get; set; }
    public string? InsuranceDocumentUrl   { get; set; }
}

public class StaffListRequest : PagedRequest { }

public class StaffResponse
{
    public int      Id          { get; set; }
    public string   StaffId     { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Role        { get; set; } = string.Empty;
    public string   Designation { get; set; } = string.Empty;
    public string   Contact     { get; set; } = string.Empty;
    public string   Email       { get; set; } = string.Empty;
    public string   Address     { get; set; } = string.Empty;
    public string   Username    { get; set; } = string.Empty;
    public string   LoginAccess { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public string   Remarks     { get; set; } = string.Empty;

    // Identity
    public string  EmiratesId  { get; set; } = string.Empty;
    public string  PassportNo  { get; set; } = string.Empty;
    public string  Nationality { get; set; } = string.Empty;
    public string  JobTitle    { get; set; } = string.Empty;
    public string? MoveInDate  { get; set; }
    public string? VisaExpiry  { get; set; }

    // Document dates
    public string? EmiratesIdIssueDate    { get; set; }
    public string? EmiratesIdExpiryDate   { get; set; }
    public string? PassportIssueDate      { get; set; }
    public string? PassportExpiryDate     { get; set; }
    public string? LabourCardIssueDate    { get; set; }
    public string? LabourCardExpiryDate   { get; set; }
    public string? IloeIssueDate          { get; set; }
    public string? IloeExpiryDate         { get; set; }
    public string? InsuranceIssueDate     { get; set; }
    public string? InsuranceExpiryDate    { get; set; }

    // Document URLs (Cloudinary)
    public string? EmiratesIdDocument  { get; set; }
    public string? PassportDocument    { get; set; }
    public string? LabourCardDocument  { get; set; }
    public string? IloeDocument        { get; set; }
    public string? InsuranceDocument   { get; set; }

    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
