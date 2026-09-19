using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ══════════════════════════════════════════════════════════════════════════════
// List Request
// ══════════════════════════════════════════════════════════════════════════════
public class OutsourceMoneyListRequest : PagedRequest
{
    public string? Search       { get; set; }
    public int?    CampId       { get; set; }
    public int?    FundPoolId   { get; set; }
    public string? Mode         { get; set; }
    public string? Month        { get; set; }
    public string? FromDate     { get; set; }
    public string? ToDate       { get; set; }
}

// ══════════════════════════════════════════════════════════════════════════════
// Create Request
// ══════════════════════════════════════════════════════════════════════════════
public class CreateOutsourceMoneyRequest
{
    [Required(ErrorMessage = "Date is required")]
    public string Date { get; set; } = string.Empty;

    [MaxLength(100, ErrorMessage = "Month cannot exceed 100 characters")]
    public string? Month { get; set; }

    [Required(ErrorMessage = "Camp is required")]
    public int? CampId { get; set; }

    [Required(ErrorMessage = "Fund Pool is required")]
    public int? FundPoolId { get; set; }

    [Required(ErrorMessage = "Amount is required")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Amount must be greater than 0")]
    public decimal Amount { get; set; }

    [Required(ErrorMessage = "Mode is required")]
    [MaxLength(100, ErrorMessage = "Mode cannot exceed 100 characters")]
    public string Mode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Purpose is required")]
    [MaxLength(500, ErrorMessage = "Purpose cannot exceed 500 characters")]
    public string Purpose { get; set; } = string.Empty;

    [MaxLength(1000, ErrorMessage = "Remarks cannot exceed 1000 characters")]
    public string? Remarks { get; set; }

    [MaxLength(200, ErrorMessage = "Reference Number cannot exceed 200 characters")]
    public string? ReferenceNo { get; set; }
}

// ══════════════════════════════════════════════════════════════════════════════
// Update Request
// ══════════════════════════════════════════════════════════════════════════════
public class UpdateOutsourceMoneyRequest
{
    [Required(ErrorMessage = "Date is required")]
    public string Date { get; set; } = string.Empty;

    [MaxLength(100, ErrorMessage = "Month cannot exceed 100 characters")]
    public string? Month { get; set; }

    [Required(ErrorMessage = "Camp is required")]
    public int? CampId { get; set; }

    [Required(ErrorMessage = "Fund Pool is required")]
    public int? FundPoolId { get; set; }

    [Required(ErrorMessage = "Amount is required")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Amount must be greater than 0")]
    public decimal Amount { get; set; }

    [Required(ErrorMessage = "Mode is required")]
    [MaxLength(100, ErrorMessage = "Mode cannot exceed 100 characters")]
    public string Mode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Purpose is required")]
    [MaxLength(500, ErrorMessage = "Purpose cannot exceed 500 characters")]
    public string Purpose { get; set; } = string.Empty;

    [MaxLength(1000, ErrorMessage = "Remarks cannot exceed 1000 characters")]
    public string? Remarks { get; set; }

    [MaxLength(200, ErrorMessage = "Reference Number cannot exceed 200 characters")]
    public string? ReferenceNo { get; set; }
}

// ══════════════════════════════════════════════════════════════════════════════
// Response
// ══════════════════════════════════════════════════════════════════════════════
public class OutsourceMoneyResponse
{
    public int      Id           { get; set; }
    public string   Date         { get; set; } = string.Empty;
    public string   Month        { get; set; } = string.Empty;
    public int      CampId       { get; set; }
    public string   CampName     { get; set; } = string.Empty;
    public int      FundPoolId   { get; set; }
    public string   FundPoolName { get; set; } = string.Empty;
    public decimal  Amount       { get; set; }
    public string   Mode         { get; set; } = string.Empty;
    public string   Purpose      { get; set; } = string.Empty;
    public string   Remarks      { get; set; } = string.Empty;
    public string   ReferenceNo  { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
    public DateTime UpdatedAt    { get; set; }
}
