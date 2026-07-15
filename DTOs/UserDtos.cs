using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

public class CreateUserRequest
{
    public string  Name        { get; set; } = string.Empty;
    public string  Username    { get; set; } = string.Empty;
    public string  Password    { get; set; } = string.Empty;
    public string  Role        { get; set; } = string.Empty;
    public string  Source      { get; set; } = string.Empty;
    public int?    SourceId    { get; set; }
    public string  Contact     { get; set; } = string.Empty;
    public string? Email       { get; set; }
    public bool    IsAdmin     { get; set; } = false;
    public string  MenuAccess  { get; set; } = "{}";
    public string  LoginAccess { get; set; } = "enabled";
    public string  Status      { get; set; } = "Active";
}

public class UpdateUserRequest
{
    public string  Name        { get; set; } = string.Empty;
    public string  Role        { get; set; } = string.Empty;
    public string  Source      { get; set; } = string.Empty;
    public int?    SourceId    { get; set; }
    public string  Contact     { get; set; } = string.Empty;
    public string? Email       { get; set; }
    public bool    IsAdmin     { get; set; } = false;
    public string  MenuAccess  { get; set; } = "{}";
    public string  LoginAccess { get; set; } = "enabled";
    public string  Status      { get; set; } = "Active";
}

public class ResetPasswordRequest
{
    public string NewPassword { get; set; } = string.Empty;
}

public class UserStatsResponse
{
    public int TotalUsers     { get; set; }
    public int ActiveUsers    { get; set; }
    public int InactiveUsers  { get; set; }
    public int RolesAssigned  { get; set; }
}

public class UpdateLoginAccessRequest
{
    public string LoginAccess { get; set; } = "enabled";
}

public class UserListRequest : PagedRequest
{
    public string? Role   { get; set; }
    public string? Source { get; set; }
}

public class UserResponse
{
    public int      Id          { get; set; }
    public string   UserId      { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Username    { get; set; } = string.Empty;
    public string   Password    { get; set; } = string.Empty;
    public string   Role        { get; set; } = string.Empty;
    public string   Source      { get; set; } = string.Empty;
    public int?     SourceId    { get; set; }
    public string   Contact     { get; set; } = string.Empty;
    public string   Email       { get; set; } = string.Empty;
    public bool     IsAdmin     { get; set; }
    public string   LoginAccess { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public string   MenuAccess  { get; set; } = "{}";
    public DateTime? LastLogin  { get; set; }
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
}
