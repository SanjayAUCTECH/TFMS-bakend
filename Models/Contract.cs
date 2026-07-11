namespace TFMS_software_api.Models;

public class Contract
{
    public int           Id              { get; set; }
    public string        ContractId      { get; set; } = string.Empty;
    public int           TenantId        { get; set; }
    public string        TenantName      { get; set; } = string.Empty;
    public int           CampId          { get; set; }
    public string        CampName        { get; set; } = string.Empty;
    public DateTime      StartDate       { get; set; }
    public int           Months          { get; set; }
    public DateTime      EndDate         { get; set; }
    public decimal       MonthlyTotal    { get; set; }
    public decimal       ContractTotal   { get; set; }
    public decimal       SecurityDeposit { get; set; }
    public string        InstallmentType { get; set; } = "monthly";
    public string        IssuedBy        { get; set; } = string.Empty;
    public string        Notes           { get; set; } = string.Empty;
    public decimal       LessorAmount    { get; set; }
    public string        Status          { get; set; } = "Active";
    // ── Property Information ──────────────────────────────────────────────
    public string        ContractPropertyUsage  { get; set; } = string.Empty;
    public string        ContractBuildingName   { get; set; } = string.Empty;
    public string        ContractPropertyType   { get; set; } = string.Empty;
    public string        ContractLocation       { get; set; } = string.Empty;
    public string        ContractPropertyNo     { get; set; } = string.Empty;
    public string        ContractPropertyArea   { get; set; } = string.Empty;
    public string        ContractPremisesNo     { get; set; } = string.Empty;
    public string        ContractPaymentMode    { get; set; } = string.Empty;
    public string        ContractPlotNo         { get; set; } = string.Empty;
    public string        ContractMakaniNo       { get; set; } = string.Empty;
    // ─────────────────────────────────────────────────────────────────────
    public decimal       TotalPaid       { get; set; }
    public decimal       TotalDue        { get; set; }
    public decimal?      LastPaymentAmount { get; set; }
    public DateTime?     LastPaymentDate   { get; set; }
    public DateTime      CreatedAt       { get; set; }
    public DateTime      UpdatedAt       { get; set; }
    public List<int>     RoomIds         { get; set; } = new();
    public List<Payment> Payments        { get; set; } = new();
}

public class ContractRoom
{
    public int    Id         { get; set; }
    public string ContractId { get; set; } = string.Empty;
    public int    RoomId     { get; set; }
}
