using System.ComponentModel.DataAnnotations;
using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ═══════════════════════════════════════════════════════
//  SDCollection DTOs
// ═══════════════════════════════════════════════════════

public class SDCollectionItem
{
    [Required] public DateTime Date    { get; set; }
    [Required][Range(1, int.MaxValue)] public int SalonId  { get; set; }
    public int?      StaffId     { get; set; }          // optional
    public int?      HeadId      { get; set; }          // optional
    public string?   Mode        { get; set; } = "Cash";
    public decimal?  Amount      { get; set; }          // optional
    public string?   Description { get; set; }          // optional
    public string?   Status      { get; set; } = "Active";
}

/// <summary>Bulk create — array in Collections</summary>
public class BulkCreateSDCollectionRequest
{
    [Required][MinLength(1, ErrorMessage = "At least one collection row is required.")]
    public List<SDCollectionItem> Collections { get; set; } = new();
}

public class UpdateSDCollectionRequest
{
    [Required] public DateTime Date    { get; set; }
    [Required][Range(1, int.MaxValue)] public int SalonId  { get; set; }
    public int?      StaffId     { get; set; }
    public int?      HeadId      { get; set; }
    public string?   Mode        { get; set; } = "Cash";
    public decimal?  Amount      { get; set; }
    public string?   Description { get; set; }
    public string?   Status      { get; set; } = "Active";
}

public class SDCollectionListRequest : PagedRequest
{
    public int?    SalonId  { get; set; }
    public int?    StaffId  { get; set; }
    public string? DateFrom { get; set; }
    public string? DateTo   { get; set; }
}

public class SDCollectionResponse
{
    public int       CollectionId { get; set; }
    public DateTime  Date         { get; set; }
    public int       SalonId      { get; set; }
    public string?   SalonName    { get; set; }
    public int?      StaffId      { get; set; }
    public string?   StaffName    { get; set; }
    public int?      HeadId       { get; set; }
    public string?   HeadName     { get; set; }
    public string?   Mode         { get; set; }
    public decimal?  Amount       { get; set; }
    public string?   Description  { get; set; }
    public string?   Status       { get; set; }
    public DateTime  CreatedAt    { get; set; }
    public DateTime? UpdatedAt    { get; set; }
}

// ═══════════════════════════════════════════════════════
//  SDExpence DTOs
// ═══════════════════════════════════════════════════════

public class SDExpenceItem
{
    [Required] public DateTime Date    { get; set; }
    [Required][Range(1, int.MaxValue)] public int SalonId  { get; set; }
    public int?      HeadId        { get; set; }
    public string?   ExpenceType   { get; set; } = "DC Expense";
    public string?   Mode          { get; set; } = "Cash";
    public decimal?  Amount        { get; set; }
    public string?   Description   { get; set; }
    public string?   Status        { get; set; } = "Active";
}

/// <summary>Bulk create — array in Expences</summary>
public class BulkCreateSDExpenceRequest
{
    [Required][MinLength(1, ErrorMessage = "At least one expense row is required.")]
    public List<SDExpenceItem> Expences { get; set; } = new();
}

public class UpdateSDExpenceRequest
{
    [Required] public DateTime Date    { get; set; }
    [Required][Range(1, int.MaxValue)] public int SalonId  { get; set; }
    public int?      HeadId        { get; set; }
    public string?   ExpenceType   { get; set; } = "DC Expense";
    public string?   Mode          { get; set; } = "Cash";
    public decimal?  Amount        { get; set; }
    public string?   Description   { get; set; }
    public string?   Status        { get; set; } = "Active";
}

public class SDExpenceListRequest : PagedRequest
{
    public int?    SalonId     { get; set; }
    public string? ExpenceType { get; set; }
    public string? DateFrom    { get; set; }
    public string? DateTo      { get; set; }
}

public class SDExpenceResponse
{
    public int       ExpenceId     { get; set; }
    public DateTime  Date          { get; set; }
    public int       SalonId       { get; set; }
    public string?   SalonName     { get; set; }
    public int?      HeadId        { get; set; }
    public string?   HeadName      { get; set; }
    public string?   ExpenceType   { get; set; }
    public string?   Mode          { get; set; }
    public decimal?  Amount        { get; set; }
    public string?   Description   { get; set; }
    public string?   Status        { get; set; }
    public DateTime  CreatedAt     { get; set; }
    public DateTime? UpdatedAt     { get; set; }
}

// ═══════════════════════════════════════════════════════
//  Combined Daily Posting (both arrays in one call)
// ═══════════════════════════════════════════════════════

public class SalonDailyPostingRequest
{
    public List<SDCollectionItem> Collections { get; set; } = new();
    public List<SDExpenceItem>    Expences    { get; set; } = new();
}

public class SalonDailyPostingResponse
{
    public int CollectionsInserted { get; set; }
    public int ExpencesInserted    { get; set; }
    public string Message          { get; set; } = string.Empty;
}
