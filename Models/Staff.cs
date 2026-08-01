namespace TFMS_software_api.Models;

public class Staff
{
    public int      Id          { get; set; }
    public string   StaffId     { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Role        { get; set; } = "Staff";
    public string?  Designation { get; set; }
    public string?  Contact     { get; set; }
    public string?  Email       { get; set; }
    public string?  Address     { get; set; }
    public string?  Username    { get; set; }
    public string?  Password    { get; set; }
    public string   LoginAccess { get; set; } = "enabled";
    public string   Status      { get; set; } = "Active";
    public string?  Remarks     { get; set; }

    // Identity & Employment
    public string?   EmiratesId    { get; set; }
    public string?   PassportNo    { get; set; }
    public string?   Nationality   { get; set; }
    public string?   JobTitle      { get; set; }
    public DateTime? MoveInDate    { get; set; }
    public DateTime? VisaExpiry    { get; set; }

    // 5 New Fields
    public string?   LabourCardNo    { get; set; }
    public DateTime? DateOfBirth     { get; set; }
    public DateTime? FitnessExpireDM { get; set; }
    public string?   IloeNo          { get; set; }
    public string?   InsuranceNo     { get; set; }

    // Document dates
    public DateTime? EmiratesIdIssueDate    { get; set; }
    public DateTime? EmiratesIdExpiryDate   { get; set; }
    public DateTime? PassportIssueDate      { get; set; }
    public DateTime? PassportExpiryDate     { get; set; }
    public DateTime? LabourCardIssueDate    { get; set; }
    public DateTime? LabourCardExpiryDate   { get; set; }
    public DateTime? IloeIssueDate          { get; set; }
    public DateTime? IloeExpiryDate         { get; set; }
    public DateTime? InsuranceIssueDate     { get; set; }
    public DateTime? InsuranceExpiryDate    { get; set; }

    // Document URLs (Cloudinary) — null means no document
    public string? EmiratesIdDocument  { get; set; }
    public string? PassportDocument    { get; set; }
    public string? LabourCardDocument  { get; set; }
    public string? IloeDocument        { get; set; }
    public string? InsuranceDocument   { get; set; }

    // Company
    public int?   CompanyId   { get; set; }
    public string CompanyName { get; set; } = string.Empty;

    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
    // Audit
    public int?  AddedBy   { get; set; }
    public int?  UpdatedBy { get; set; }
    public bool  IsDeleted { get; set; }
}
