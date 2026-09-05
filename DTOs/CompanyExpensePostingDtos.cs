using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ═══════════════════════════════════════════════════════
//  REQUEST DTOs
// ═══════════════════════════════════════════════════════

public class CreateCompanyExpensePostingRequest
{
    [Required(ErrorMessage = "Date is required.")]
    public DateTime Date { get; set; }

    [Required(ErrorMessage = "Type is required.")]
    [MaxLength(100)]
    public string Type { get; set; } = string.Empty;  // Salary, Dewa, Rent, etc.

    [MaxLength(200)]
    public string? RecipientName { get; set; }

    [MaxLength(200)]
    public string? Head { get; set; }

    [Required(ErrorMessage = "Amount is required.")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Amount must be greater than 0.")]
    public decimal Amount { get; set; }

    [MaxLength(50)]
    public string Mode { get; set; } = "Cash";  // Cash, Bank, Cheque, Online

    public int? SalonId { get; set; }

    [MaxLength(500)]
    public string? Description { get; set; }

    public string Status { get; set; } = "Active";
}

public class UpdateCompanyExpensePostingRequest
{
    [Required(ErrorMessage = "Date is required.")]
    public DateTime Date { get; set; }

    [Required(ErrorMessage = "Type is required.")]
    [MaxLength(100)]
    public string Type { get; set; } = string.Empty;

    [MaxLength(200)]
    public string? RecipientName { get; set; }

    [MaxLength(200)]
    public string? Head { get; set; }

    [Required(ErrorMessage = "Amount is required.")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Amount must be greater than 0.")]
    public decimal Amount { get; set; }

    [MaxLength(50)]
    public string Mode { get; set; } = "Cash";

    public int? SalonId { get; set; }

    [MaxLength(500)]
    public string? Description { get; set; }

    public string Status { get; set; } = "Active";
}

public class CompanyExpensePostingListRequest : PagedRequest
{
    public int?    SalonId  { get; set; }
    public string? Type     { get; set; }
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
}

// ═══════════════════════════════════════════════════════
//  RESPONSE DTOs
// ═══════════════════════════════════════════════════════

public class CompanyExpensePostingResponse
{
    public int       Id            { get; set; }
    public DateTime  Date          { get; set; }
    public string?   Type          { get; set; }
    public string?   RecipientName { get; set; }
    public string?   Head          { get; set; }
    public decimal   Amount        { get; set; }
    public string?   Mode          { get; set; }
    public int?      SalonId       { get; set; }
    public string?   SalonName     { get; set; }
    public string?   Description   { get; set; }
    public string?   Status        { get; set; }
    public DateTime  CreatedAt     { get; set; }
    public DateTime? UpdatedAt     { get; set; }
}

public class CompanyExpenseSummaryResponse
{
    public string?  Type         { get; set; }
    public int      TotalEntries { get; set; }
    public decimal  TotalAmount  { get; set; }
}
