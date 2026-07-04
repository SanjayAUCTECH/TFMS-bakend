using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── Request DTOs ──────────────────────────────────────────────────────────────

public class CreateUserRequest
{
    [Required, MaxLength(200)] public string Name        { get; set; } = string.Empty;
    [Required, MaxLength(50)]  public string Username    { get; set; } = string.Empty;
    [Required, MinLength(6)]   public string Password    { get; set; } = string.Empty;
    [Required, MaxLength(50)]  public string Role        { get; set; } = string.Empty;
    [MaxLength(50)]            public string Source      { get; set; } = string.Empty;
    public int?                              SourceId    { get; set; }
    [MaxLength(20)]            public string Contact     { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email   { get; set; } = string.Empty;
    public bool                              IsAdmin     { get; set; } = false;
    public string                            MenuAccess  { get; set; } = "{}";
    public string                            LoginAccess { get; set; } = "enabled";
    public string                            Status      { get; set; } = "Active";
}

public class UpdateUserRequest
{
    [Required, MaxLength(200)] public string Name        { get; set; } = string.Empty;
    [Required, MaxLength(50)]  public string Role        { get; set; } = string.Empty;
    [MaxLength(50)]            public string Source      { get; set; } = string.Empty;
    public int?                              SourceId    { get; set; }
    [MaxLength(20)]            public string Contact     { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email   { get; set; } = string.Empty;
    public bool                              IsAdmin     { get; set; } = false;
    public string                            MenuAccess  { get; set; } = "{}";
    public string                            LoginAccess { get; set; } = "enabled";
    public string                            Status      { get; set; } = "Active";
}

public class ResetPasswordRequest
{
    [Required, MinLength(4)] public string NewPassword { get; set; } = string.Empty;
}

// ── Login Access ──────────────────────────────────────────────────────────────
public class UpdateLoginAccessRequest
{
    [Required] public string LoginAccess { get; set; } = "enabled";  // enabled | disabled
}

public class UserListRequest : PagedRequest
{
    public string? Role   { get; set; }
    public string? Source { get; set; }
}

// ── Response DTOs ─────────────────────────────────────────────────────────────

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
