namespace TFMS_software_api.DTOs;

/// <summary>One row in pivot = one date</summary>
public class SDCollectionPivotRow
{
    public string Date       { get; set; } = string.Empty;   // DD/MM/YYYY

    /// <summary>CollectionId per staff for delete/detail — Key=StaffName, Value=CollectionId</summary>
    public Dictionary<string, int> CollectionIds { get; set; } = new();

    /// <summary>Key = StaffName, Value = Amount</summary>
    public Dictionary<string, decimal> StaffAmounts { get; set; } = new();

    public decimal DCExpense   { get; set; }
    public decimal COExpense   { get; set; }
    public decimal TotalExpense{ get; set; }
}

public class SDCollectionPivotResponse
{
    /// <summary>Distinct staff names — use as column headers</summary>
    public List<string> StaffColumns { get; set; } = new();

    /// <summary>Pivot rows — one per date (paginated)</summary>
    public List<SDCollectionPivotRow> Rows { get; set; } = new();

    /// <summary>Total row (across ALL dates, not just current page)</summary>
    public SDCollectionPivotRow Totals { get; set; } = new();

    // Pagination meta
    public int TotalRecords { get; set; }
    public int PageNumber   { get; set; }
    public int PageSize     { get; set; }
    public int TotalPages   { get; set; }
}

/// <summary>Query params — all optional</summary>
public class SDCollectionPivotRequest
{
    public int?    SalonId    { get; set; }
    public int?    StaffId    { get; set; }
    public string? DateFrom   { get; set; }
    public string? DateTo     { get; set; }
    public string? SearchText { get; set; }  // search by staff name or salon name
    public int     PageNumber { get; set; } = 1;
    public int     PageSize   { get; set; } = 10;
}
