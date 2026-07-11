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
    // ── New fields ────────────────────────────────────────────────────────
    public string    EmiratesId  { get; set; } = string.Empty;
    public string    PassportNo  { get; set; } = string.Empty;
    public string    Nationality { get; set; } = string.Empty;
    public string    JobTitle    { get; set; } = string.Empty;
    public DateTime? MoveInDate  { get; set; }
    public DateTime? VisaExpiry  { get; set; }
    // ─────────────────────────────────────────────────────────────────────
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
