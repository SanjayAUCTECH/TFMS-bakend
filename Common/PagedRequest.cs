using Microsoft.AspNetCore.Mvc.ModelBinding;
using System.Text.Json.Serialization;

namespace TFMS_software_api.Common;

/// <summary>
/// Standard paginated list request — all fields are optional.
/// Omit PageSize (or set to 0) to get ALL records without pagination.
/// </summary>
public class PagedRequest
{
    /// <summary>Page number (1-based). Optional — defaults to 1.</summary>
    public int?    PageNumber    { get; set; }

    /// <summary>
    /// Records per page. Optional — omit or 0 = return ALL records.
    /// </summary>
    public int?    PageSize      { get; set; }

    /// <summary>Free-text search. Optional.</summary>
    public string? SearchText    { get; set; }

    /// <summary>Column name to sort by. Optional.</summary>
    public string? SortBy        { get; set; }

    /// <summary>Sort direction: ASC or DESC. Optional, defaults to ASC.</summary>
    public string? SortDirection { get; set; }

    /// <summary>Filter by Status: Active | Inactive. Optional — omit for all.</summary>
    public string? Status        { get; set; }

    // ── Resolved helpers — hidden from Swagger & model binding ───────────────
    [BindNever, JsonIgnore]
    public int ResolvedPageNumber => PageNumber is > 0 ? PageNumber.Value : 1;

    /// <summary>0 / null means "all" — stored procs handle int.MaxValue as no-limit.</summary>
    [BindNever, JsonIgnore]
    public int ResolvedPageSize => (PageSize is > 0) ? PageSize.Value : int.MaxValue;

    [BindNever, JsonIgnore]
    public string ResolvedSortDir => SortDirection?.ToUpper() == "DESC" ? "DESC" : "ASC";
}
