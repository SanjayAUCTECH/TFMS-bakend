using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── Request DTOs ──────────────────────────────────────────────────────────────

public class CreateIncomeRequest
{
    public DateTime Date         { get; set; }
    [MaxLength(50)]  public string Mode       { get; set; } = string.Empty;
    [MaxLength(200)] public string Head       { get; set; } = string.Empty;
    public int?    FundPoolId { get; set; }
    public decimal Amount     { get; set; }
    [MaxLength(500)] public string Purpose   { get; set; } = string.Empty;
    [MaxLength(50)]  public string Source    { get; set; } = string.Empty;
    [MaxLength(50)]  public string SourceRef { get; set; } = string.Empty;
}

public class UpdateIncomeRequest
{
    public DateTime Date         { get; set; }
    [MaxLength(50)]  public string Mode       { get; set; } = string.Empty;
    [MaxLength(200)] public string Head       { get; set; } = string.Empty;
    public int?    FundPoolId { get; set; }
    public decimal Amount     { get; set; }
    [MaxLength(500)] public string Purpose   { get; set; } = string.Empty;
    [MaxLength(50)]  public string Source    { get; set; } = string.Empty;
    [MaxLength(50)]  public string SourceRef { get; set; } = string.Empty;
}

public class IncomeListRequest : PagedRequest
{
    public string? DateFrom   { get; set; }
    public string? DateTo     { get; set; }
    public string? Head       { get; set; }
    public string? FundPool   { get; set; }
}

// ── Response DTOs ─────────────────────────────────────────────────────────────

public class IncomeResponse
{
    public int      Id           { get; set; }
    public string   IncomeId     { get; set; } = string.Empty;
    public DateTime Date         { get; set; }
    public string   Mode         { get; set; } = string.Empty;
    public string   Head         { get; set; } = string.Empty;
    public string   FundPool     { get; set; } = string.Empty;
    public string   FundPoolName { get; set; } = string.Empty;
    public decimal  Amount       { get; set; }
    public string   Purpose      { get; set; } = string.Empty;
    public string   Source       { get; set; } = string.Empty;
    public string   SourceRef    { get; set; } = string.Empty;
    public string   ContractId   { get; set; } = string.Empty;
    public string   ContractCode { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
    public DateTime UpdatedAt    { get; set; }
}
