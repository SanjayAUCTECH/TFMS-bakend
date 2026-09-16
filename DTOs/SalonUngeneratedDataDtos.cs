namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────
public class SalonUngeneratedDataRequest
{
    public int?    SalonId  { get; set; }
    public string? DateFrom { get; set; }   // e.g. "2026-08-01"
    public string? DateTo   { get; set; }   // e.g. "2026-08-31"
}

// ── Per Salon Row ─────────────────────────────────────────────
public class SalonUngeneratedDataRow
{
    public int     SalonId                    { get; set; }
    public string  SalonName                  { get; set; } = string.Empty;
    public string  DateFrom                   { get; set; } = string.Empty;
    public string  DateTo                     { get; set; } = string.Empty;

    /// <summary>SDCollection SUM(Amount) for date range</summary>
    public decimal UngeneratedCollection      { get; set; }

    /// <summary>CompanyExpensePosting SUM(Amount) where Head != 'SALARY'</summary>
    public decimal UngeneratedCompanyExpense  { get; set; }

    /// <summary>CompanyExpensePosting SUM(Amount) where Head = 'SALARY'</summary>
    public decimal UngeneratedStaffSalary     { get; set; }
}

// ── Summary ───────────────────────────────────────────────────
public class SalonUngeneratedDataSummary
{
    public decimal TotalUngeneratedCollection     { get; set; }
    public decimal TotalUngeneratedCompanyExpense { get; set; }
    public decimal TotalUngeneratedStaffSalary    { get; set; }
}

// ── Full Response ─────────────────────────────────────────────
public class SalonUngeneratedDataResponse
{
    public SalonUngeneratedDataSummary    Summary { get; set; } = new();
    public List<SalonUngeneratedDataRow>  Rows    { get; set; } = new();
}
