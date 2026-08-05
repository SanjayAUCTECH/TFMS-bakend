using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

public class CreateCampbossRequest
{
    public string? Name        { get; set; }
    public string? Contact     { get; set; }
    public string? Email       { get; set; }
    public string? Address     { get; set; }
    public string? Username    { get; set; }
    public string? Password    { get; set; }
    public string? LoginAccess { get; set; }
    public string? Status      { get; set; }
    public string? Remarks     { get; set; }
    public string? EmiratesId  { get; set; }
    public string? PassportNo  { get; set; }
    public string? Nationality { get; set; }
}

public class UpdateCampbossRequest
{
    public string? Name        { get; set; }
    public string? Contact     { get; set; }
    public string? Email       { get; set; }
    public string? Address     { get; set; }
    public string? Username    { get; set; }
    public string? Password    { get; set; }
    public string? LoginAccess { get; set; }
    public string? Status      { get; set; }
    public string? Remarks     { get; set; }
    public string? EmiratesId  { get; set; }
    public string? PassportNo  { get; set; }
    public string? Nationality { get; set; }
}

public class CampbossListRequest : PagedRequest { }

public class CampbossResponse
{
    public int      Id          { get; set; }
    public string   CampbossId  { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string?  Contact     { get; set; }
    public string?  Email       { get; set; }
    public string?  Address     { get; set; }
    public string?  Username    { get; set; }
    public string   LoginAccess { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public string?  Remarks     { get; set; }
    public string?  EmiratesId  { get; set; }
    public string?  PassportNo  { get; set; }
    public string?  Nationality { get; set; }
    public List<CampbossAssignedCampResponse> AssignedCamps { get; set; } = new();
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}

public class CampbossAssignedCampResponse
{
    public int     Id       { get; set; }
    public int     CampId   { get; set; }
    public string  CampName { get; set; } = string.Empty;
    public string  Type     { get; set; } = string.Empty;
    public decimal Amount   { get; set; }
}
