using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── List Request ──────────────────────────────────────────────────
public class AlertTimeListRequest : PagedRequest
{
    public string? Status { get; set; }
}

// ── Response ──────────────────────────────────────────────────────
public class AlertTimeResponse
{
    public int      Id         { get; set; }
    public string   AlertName  { get; set; } = string.Empty;
    public int      Days       { get; set; }
    public string   Status     { get; set; } = string.Empty;
    public DateTime CreatedAt  { get; set; }
    public DateTime UpdatedAt  { get; set; }
    public int?     AddedBy    { get; set; }
    public int?     UpdatedBy  { get; set; }
}

// ── Create Request ────────────────────────────────────────────────
public class CreateAlertTimeRequest
{
    [Required(ErrorMessage = "Alert name is required")]
    [StringLength(100, ErrorMessage = "Alert name cannot exceed 100 characters")]
    public string AlertName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Days is required")]
    [Range(1, 365, ErrorMessage = "Days must be between 1 and 365")]
    public int Days { get; set; }

    public string Status { get; set; } = "Active";
}

// ── Update Request ────────────────────────────────────────────────
public class UpdateAlertTimeRequest
{
    [Required(ErrorMessage = "Alert name is required")]
    [StringLength(100, ErrorMessage = "Alert name cannot exceed 100 characters")]
    public string AlertName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Days is required")]
    [Range(1, 365, ErrorMessage = "Days must be between 1 and 365")]
    public int Days { get; set; }

    [Required(ErrorMessage = "Status is required")]
    public string Status { get; set; } = "Active";
}
