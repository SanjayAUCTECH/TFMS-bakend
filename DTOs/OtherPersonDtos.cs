using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateOtherPersonRequest
{
    [Required, MaxLength(50)]  public string Designation { get; set; } = string.Empty;
    [Required, MaxLength(200)] public string Name        { get; set; } = string.Empty;
    [Required, MaxLength(20)]  public string Mobile      { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email   { get; set; } = string.Empty;
    [MaxLength(300)] public string Address  { get; set; } = string.Empty;
    [MaxLength(100)] public string City     { get; set; } = string.Empty;
    [MaxLength(100)] public string State    { get; set; } = string.Empty;
    [MaxLength(10)]  public string Pincode  { get; set; } = string.Empty;
    [MaxLength(300)] public string Remarks  { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class UpdateOtherPersonRequest
{
    [Required, MaxLength(50)]  public string Designation { get; set; } = string.Empty;
    [Required, MaxLength(200)] public string Name        { get; set; } = string.Empty;
    [Required, MaxLength(20)]  public string Mobile      { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email   { get; set; } = string.Empty;
    [MaxLength(300)] public string Address  { get; set; } = string.Empty;
    [MaxLength(100)] public string City     { get; set; } = string.Empty;
    [MaxLength(100)] public string State    { get; set; } = string.Empty;
    [MaxLength(10)]  public string Pincode  { get; set; } = string.Empty;
    [MaxLength(300)] public string Remarks  { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class OtherPersonListRequest : Common.PagedRequest
{
    public string? Designation { get; set; }
}

public class OtherPersonResponse
{
    public int      Id          { get; set; }
    public string   Code        { get; set; } = string.Empty;
    public string   Designation { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Mobile      { get; set; } = string.Empty;
    public string   Email       { get; set; } = string.Empty;
    public string   Address     { get; set; } = string.Empty;
    public string   City        { get; set; } = string.Empty;
    public string   State       { get; set; } = string.Empty;
    public string   Pincode     { get; set; } = string.Empty;
    public string   Remarks     { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
