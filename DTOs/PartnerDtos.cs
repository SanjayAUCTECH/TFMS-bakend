using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

// ── Request DTOs ──────────────────────────────────────────────────────────────

public class CreatePartnerRequest
{
    [Required, MaxLength(200)] public string Name    { get; set; } = string.Empty;
    [MaxLength(100)]           public string Contact { get; set; } = string.Empty;
    [MaxLength(20)]            public string Mobile  { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class UpdatePartnerRequest
{
    [Required, MaxLength(200)] public string Name    { get; set; } = string.Empty;
    [MaxLength(100)]           public string Contact { get; set; } = string.Empty;
    [MaxLength(20)]            public string Mobile  { get; set; } = string.Empty;
    [MaxLength(150), EmailAddress] public string Email { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class PartnerListRequest : Common.PagedRequest { }

// ── Response DTOs ─────────────────────────────────────────────────────────────

public class PartnerResponse
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Contact   { get; set; } = string.Empty;
    public string   Mobile    { get; set; } = string.Empty;
    public string   Email     { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
