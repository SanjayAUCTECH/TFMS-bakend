namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────────────────
public class MISDashboardRequest
{
    /// <summary>Optional camp filter. Omit for all camps.</summary>
    public int?    CampId { get; set; }

    /// <summary>Optional month filter. Format: yyyy-MM e.g. '2026-07'</summary>
    public string? Month  { get; set; }
}

// ── RS1: Collection row per camp ──────────────────────────────────────────
public class MISCollectionRow
{
    public int     CampId     { get; set; }
    public string  CampCode   { get; set; } = string.Empty;
    public string  CampName   { get; set; } = string.Empty;   // "property" in UI
    public int     NetUnits   { get; set; }
    public int     Occupied   { get; set; }
    public int     Vacant     { get; set; }
    public decimal AvgRent    { get; set; }
    public decimal Rental     { get; set; }
    public decimal Collected  { get; set; }
    public decimal Discount   { get; set; }
    public decimal Balance    { get; set; }
    public decimal ReceivedSD { get; set; }
    public decimal GrandTotal => Collected + ReceivedSD;  // Rental + SD
}

// ── RS2: Expense category totals ──────────────────────────────────────────
public class MISExpenseCategoryRow
{
    public string  Category     { get; set; } = string.Empty;
    public decimal Total        { get; set; }
    public decimal TotalFiltered{ get; set; }
}

// ── RS3: Expense detail per camp per category ─────────────────────────────
public class MISExpenseDetailRow
{
    public string  Category { get; set; } = string.Empty;
    public int?    CampId   { get; set; }
    public string  CampName { get; set; } = string.Empty;
    public decimal Amount   { get; set; }
}

// ── RS4: Summary Cards ────────────────────────────────────────────────────
public class MISDashboardCards
{
    public decimal TotalCollection { get; set; }
    public decimal TotalExpense    { get; set; }
    public int     TotalUnits      { get; set; }
    public int     TotalOccupied   { get; set; }
    public int     TotalVacant     { get; set; }
}

// ── Pivot expense row (built in C# from RS2 + RS3) ───────────────────────
/// <summary>One row = one expense category, columns = each camp's amount</summary>
public class MISExpensePivotRow
{
    public string                     Category    { get; set; } = string.Empty;
    public decimal                    Total       { get; set; }
    public Dictionary<string, decimal> CampAmounts { get; set; } = new();
}

// ── Pivot partner row (built in C# from RS5) ─────────────────────────────
/// <summary>
/// Partner profit data from PartnerTrans
/// Type='Expense' AND AccountHead='Partner Profit'
/// </summary>
public class MISPartnerPivotRow
{
    public int     PartnerId    { get; set; }
    public string  PartnerName  { get; set; } = string.Empty;
    public decimal Total        { get; set; }  // SUM of all PartnerTrans amounts
    public Dictionary<string, decimal> CampAmounts { get; set; } = new();  // empty — no camp breakd own in PartnerTrans
}

// ── Full Response ─────────────────────────────────────────────────────────
public class MISDashboardResponse
{
    public MISDashboardCards            Cards          { get; set; } = new();
    public List<MISCollectionRow>       CollectionData { get; set; } = new();
    public List<MISExpensePivotRow>     ExpenseData    { get; set; } = new();
    public List<MISPartnerPivotRow>     PartnerData    { get; set; } = new();
    public List<string>                 CampNames      { get; set; } = new();  // for dynamic columns
}
