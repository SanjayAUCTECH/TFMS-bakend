namespace TFMS_software_api.Models;

public class Staff
{
    public int      Id          { get; set; }
    public string   StaffId     { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Role        { get; set; } = "Staff";
    public string   Designation { get; set; } = string.Empty;
    public string   Contact     { get; set; } = string.Empty;
    public string   Email       { get; set; } = string.Empty;
    public string   Address     { get; set; } = string.Empty;
    public string   Username    { get; set; } = string.Empty;
    public string   Password    { get; set; } = string.Empty;
    public string   LoginAccess { get; set; } = "enabled";
    public string   Status      { get; set; } = "Active";
    public string   Remarks     { get; set; } = string.Empty;

    // Identity & Employment
    public string    EmiratesId  { get; set; } = string.Empty;
    public string    PassportNo  { get; set; } = string.Empty;
    public string    Nationality { get; set; } = string.Empty;
    public string    JobTitle    { get; set; } = string.Empty;
    public DateTime? MoveInDate  { get; set; }
    public DateTime? VisaExpiry  { get; set; }

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

    // Document URLs (Cloudinary)
    public string EmiratesIdDocument  { get; set; } = string.Empty;
    public string PassportDocument    { get; set; } = string.Empty;
    public string LabourCardDocument  { get; set; } = string.Empty;
    public string IloeDocument        { get; set; } = string.Empty;
    public string InsuranceDocument   { get; set; } = string.Empty;

    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
