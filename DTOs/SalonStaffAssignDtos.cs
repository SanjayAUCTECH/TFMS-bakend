using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

// ── Create ────────────────────────────────────────────────────────────────────
public class CreateSalonStaffAssignRequest
{
    [Required(ErrorMessage = "SalonId is required.")]
    [Range(1, int.MaxValue, ErrorMessage = "Please select a valid salon.")]
    public int SalonId { get; set; }

    [Required(ErrorMessage = "StaffId is required.")]
    [Range(1, int.MaxValue, ErrorMessage = "Please select a valid staff member.")]
    public int StaffId { get; set; }

    [Required(ErrorMessage = "Percentage is required.")]
    [Range(0.01, 100, ErrorMessage = "Percentage must be between 0.01 and 100.")]
    public decimal Percentage { get; set; }

    [MaxLength(500, ErrorMessage = "Description cannot exceed 500 characters.")]
    public string? Description { get; set; }

    public string Status { get; set; } = "Active";
}

// ── Update ────────────────────────────────────────────────────────────────────
public class UpdateSalonStaffAssignRequest
{
    [Required(ErrorMessage = "SalonId is required.")]
    [Range(1, int.MaxValue, ErrorMessage = "Please select a valid salon.")]
    public int SalonId { get; set; }

    [Required(ErrorMessage = "StaffId is required.")]
    [Range(1, int.MaxValue, ErrorMessage = "Please select a valid staff member.")]
    public int StaffId { get; set; }

    [Required(ErrorMessage = "Percentage is required.")]
    [Range(0.01, 100, ErrorMessage = "Percentage must be between 0.01 and 100.")]
    public decimal Percentage { get; set; }

    [MaxLength(500)]
    public string? Description { get; set; }

    public string Status { get; set; } = "Active";
}

// ── List request (inherits PageNumber, PageSize, SearchText, Status) ──────────
public class SalonStaffAssignListRequest : Common.PagedRequest
{
    /// <summary>Optional filter by SalonId</summary>
    public int? SalonId { get; set; }
}

// ── Response ──────────────────────────────────────────────────────────────────
public class SalonStaffAssignResponse
{
    public int       AssignId    { get; set; }
    public int       SalonId     { get; set; }
    public string    SalonName   { get; set; } = string.Empty;
    public int       StaffId     { get; set; }
    public string    StaffName   { get; set; } = string.Empty;
    public decimal   Percentage  { get; set; }
    public string?   Description { get; set; }
    public string    Status      { get; set; } = string.Empty;
    public DateTime  CreatedAt   { get; set; }
    public DateTime? UpdatedAt   { get; set; }
}
