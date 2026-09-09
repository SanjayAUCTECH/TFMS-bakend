using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ═══════════════════════════════════════════════════════
//  CURRENT FUND TRANSFER
// ═══════════════════════════════════════════════════════

public class CreateCurrentFundTransferRequest
{
    [Required] public DateTime Date { get; set; }
    [Required][Range(1, int.MaxValue)] public int FromFundPoolId { get; set; }
    public int? ToFundPoolId { get; set; }
    [Required][Range(0.01, double.MaxValue)] public decimal Amount { get; set; }
    [Required][MaxLength(20)] public string Month { get; set; } = string.Empty;
    [MaxLength(500)] public string? Description { get; set; }
    public string Status { get; set; } = "Active";
}

public class UpdateCurrentFundTransferRequest
{
    [Required] public DateTime Date { get; set; }
    [Required][Range(1, int.MaxValue)] public int FromFundPoolId { get; set; }
    public int? ToFundPoolId { get; set; }
    [Required][Range(0.01, double.MaxValue)] public decimal Amount { get; set; }
    [Required][MaxLength(20)] public string Month { get; set; } = string.Empty;
    [MaxLength(500)] public string? Description { get; set; }
    public string Status { get; set; } = "Active";
}

public class CurrentFundTransferListRequest : PagedRequest
{
    public int?    FundPoolId { get; set; }   // checks both From AND To
    public string? Month      { get; set; }
    public string? DateFrom   { get; set; }
    public string? DateTo     { get; set; }
}

public class CurrentFundTransferResponse
{
    public int       CurrentFundTransferId  { get; set; }
    public DateTime  CurrentTransferDate    { get; set; }
    public int       FromCurrentFundPoolId  { get; set; }
    public string?   FromFundPoolName       { get; set; }
    public int?      ToCurrentFundPoolId    { get; set; }
    public string?   ToFundPoolName         { get; set; }
    public decimal   CurrentAmount          { get; set; }
    public string?   CurrentMonth           { get; set; }
    public string?   Description            { get; set; }
    public string?   Status                 { get; set; }
    public string?   AddedBy                { get; set; }
    public DateTime  CreatedAt              { get; set; }
    public DateTime? UpdatedAt              { get; set; }
    public string?   TransactionType        { get; set; }  // Debit | Credit | Both
    public decimal   SignedAmount           { get; set; }  // -Amount (Debit) | +Amount (Credit)
}

// ═══════════════════════════════════════════════════════
//  BUFFER FUND TRANSFER
// ═══════════════════════════════════════════════════════

public class CreateBufferFundTransferRequest
{
    [Required] public DateTime Date { get; set; }
    [Required][Range(1, int.MaxValue)] public int FromFundPoolId { get; set; }
    public int? ToFundPoolId           { get; set; }
    public int? CurrentFundTransferId  { get; set; }
    [Required][Range(0.01, double.MaxValue)] public decimal Amount { get; set; }
    [Required][MaxLength(20)] public string Month { get; set; } = string.Empty;
    [MaxLength(500)] public string? Description { get; set; }
    public string Status { get; set; } = "Active";
}

public class UpdateBufferFundTransferRequest
{
    [Required] public DateTime Date { get; set; }
    [Required][Range(1, int.MaxValue)] public int FromFundPoolId { get; set; }
    public int? ToFundPoolId           { get; set; }
    public int? CurrentFundTransferId  { get; set; }
    [Required][Range(0.01, double.MaxValue)] public decimal Amount { get; set; }
    [Required][MaxLength(20)] public string Month { get; set; } = string.Empty;
    [MaxLength(500)] public string? Description { get; set; }
    public string Status { get; set; } = "Active";
}

public class BufferFundTransferListRequest : PagedRequest
{
    public int?    FundPoolId            { get; set; }   // checks both From AND To
    public int?    CurrentFundTransferId { get; set; }
    public string? Month                 { get; set; }
    public string? DateFrom              { get; set; }
    public string? DateTo                { get; set; }
}

public class BufferFundTransferResponse
{
    public int       BufferFundTransferId   { get; set; }
    public DateTime  BufferTransferDate     { get; set; }
    public int       FromBufferFundPoolId   { get; set; }
    public string?   FromFundPoolName       { get; set; }
    public int?      ToBufferFundPoolId     { get; set; }
    public string?   ToFundPoolName         { get; set; }
    public int?      CurrentFundTransferId  { get; set; }
    public decimal   BufferAmount           { get; set; }
    public string?   BufferMonth            { get; set; }
    public string?   Description            { get; set; }
    public string?   Status                 { get; set; }
    public string?   AddedBy                { get; set; }
    public DateTime  CreatedAt              { get; set; }
    public DateTime? UpdatedAt              { get; set; }
    public string?   TransactionType        { get; set; }  // Debit | Credit | Both
    public decimal   SignedAmount           { get; set; }  // -Amount (Debit) | +Amount (Credit)
}
