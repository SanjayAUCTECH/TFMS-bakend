using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

public class CreateStaffRequest
{
    public string  Name        { get; set; } = string.Empty;
    public string  Designation { get; set; } = string.Empty;
    public string  Contact     { get; set; } = string.Empty;
    public string? Email       { get; set; }
    public string  Address     { get; set; } = string.Empty;
    public string  Username    { get; set; } = string.Empty;
    public string  Password    { get; set; } = string.Empty;
    public string  LoginAccess { get; set; } = "enabled";
    public string  Status      { get; set; } = "Active";
    public string  Remarks     { get; set; } = string.Empty;
    public string  EmiratesId  { get; set; } = string.Empty;
    public string  PassportNo  { get; set; } = string.Empty;
    public string  Nationality { get; set; } = string.Empty;
    public string  JobTitle    { get; set; } = string.Empty;
    public string? MoveInDate  { get; set; }
    public string? VisaExpiry  { get; set; }
}

public class UpdateStaffRequest
{
    public string  Name        { get; set; } = string.Empty;
    public string  Designation { get; set; } = string.Empty;
    public string  Contact     { get; set; } = string.Empty;
    public string? Email       { get; set; }
    public string  Address     { get; set; } = string.Empty;
    public string  Username    { get; set; } = string.Empty;
    public string? Password    { get; set; }
    public string  LoginAccess { get; set; } = "enabled";
    public string  Status      { get; set; } = "Active";
    public string  Remarks     { get; set; } = string.Empty;
    public string  EmiratesId  { get; set; } = string.Empty;
    public string  PassportNo  { get; set; } = string.Empty;
    public string  Nationality { get; set; } = string.Empty;
    public string  JobTitle    { get; set; } = string.Empty;
    public string? MoveInDate  { get; set; }
    public string? VisaExpiry  { get; set; }
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
    public string   EmiratesId  { get; set; } = string.Empty;
    public string   PassportNo  { get; set; } = string.Empty;
    public string   Nationality { get; set; } = string.Empty;
    public string   JobTitle    { get; set; } = string.Empty;
    public string?  MoveInDate  { get; set; }
    public string?  VisaExpiry  { get; set; }
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
