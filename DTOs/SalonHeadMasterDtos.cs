using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

// ── Request DTOs ─────────────────────────────────────────────────────────────

public class CreateSalonHeadMasterRequest
{
    [Required(ErrorMessage = "Head Type is required.")]
    [RegularExpression("^(Income|Expense)$", ErrorMessage = "HeadType must be 'Income' or 'Expense'.")]
    public string HeadType { get; set; } = string.Empty;

    [Required(ErrorMessage = "Head Name is required.")]
    [MaxLength(150, ErrorMessage = "Head Name cannot exceed 150 characters.")]
    public string HeadName { get; set; } = string.Empty;

    public string Status { get; set; } = "Active";
}

public class UpdateSalonHeadMasterRequest
{
    [Required(ErrorMessage = "Head Type is required.")]
    [RegularExpression("^(Income|Expense)$", ErrorMessage = "HeadType must be 'Income' or 'Expense'.")]
    public string HeadType { get; set; } = string.Empty;

    [Required(ErrorMessage = "Head Name is required.")]
    [MaxLength(150)]
    public string HeadName { get; set; } = string.Empty;

    public string Status { get; set; } = "Active";
}

// List request — inherits PageNumber, PageSize, SearchText, Status from PagedRequest
public class SalonHeadMasterListRequest : Common.PagedRequest
{
    /// <summary>Filter by HeadType: Income | Expense</summary>
    public string? HeadType { get; set; }
}

// ── Response DTO ──────────────────────────────────────────────────────────────

public class SalonHeadMasterResponse
{
    public int       Id        { get; set; }
    public string    HeadType  { get; set; } = string.Empty;
    public string    HeadName  { get; set; } = string.Empty;
    public string    Status    { get; set; } = string.Empty;
    public DateTime  CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
