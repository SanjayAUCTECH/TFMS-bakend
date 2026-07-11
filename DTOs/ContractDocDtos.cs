namespace TFMS_software_api.DTOs;

/// <summary>
/// Full contract document response — used for 2-page and 3-page contract preview/print.
/// GET /api/contracts/{contractId}/document
/// Returns contract + tenant + lessor + property + rooms + installments + payment summary
/// </summary>
public class ContractDocResponse
{
    // ── Contract Info ──────────────────────────────────────────────────────
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public string   Status          { get; set; } = string.Empty;
    public DateTime StartDate       { get; set; }
    public DateTime EndDate         { get; set; }
    public int      Months          { get; set; }
    public decimal  MonthlyTotal    { get; set; }
    public decimal  ContractTotal   { get; set; }
    public decimal  SecurityDeposit { get; set; }
    public string   InstallmentType { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    public string   Notes           { get; set; } = string.Empty;
    public decimal  LessorAmount    { get; set; }
    public DateTime CreatedAt       { get; set; }

    // ── Camp / Property ────────────────────────────────────────────────────
    public int      CampId          { get; set; }
    public string   CampName        { get; set; } = string.Empty;
    public string   CampCode        { get; set; } = string.Empty;

    // ── Rooms ──────────────────────────────────────────────────────────────
    public List<ContractDocRoom> Rooms { get; set; } = new();

    // ── Tenant Info ────────────────────────────────────────────────────────
    public int     TenantId              { get; set; }
    public string  TenantName            { get; set; } = string.Empty;
    public string  TenantType            { get; set; } = string.Empty;
    public string  TenantEmiratesId      { get; set; } = string.Empty;
    public string  TenantPassport        { get; set; } = string.Empty;
    public string  TenantNationality     { get; set; } = string.Empty;
    public string  TenantContact         { get; set; } = string.Empty;
    public string  TenantWhatsapp        { get; set; } = string.Empty;
    public string  TenantEmail           { get; set; } = string.Empty;
    public string  TenantAddress         { get; set; } = string.Empty;
    public string  TenantCompany         { get; set; } = string.Empty;
    public string  TenantTradeLicense    { get; set; } = string.Empty;
    public string  TenantLicAuthority    { get; set; } = string.Empty;
    public string  TenantCoOccupants     { get; set; } = string.Empty;

    // ── Property / EJARI Fields ────────────────────────────────────────────
    public string  PlotNo          { get; set; } = string.Empty;
    public string  MakaniNo        { get; set; } = string.Empty;
    public string  PropertyArea    { get; set; } = string.Empty;
    public string  PremisesNo      { get; set; } = string.Empty;

    // ── Lessor / Owner Fields ──────────────────────────────────────────────
    public string  LessorName        { get; set; } = string.Empty;
    public string  LessorEid         { get; set; } = string.Empty;
    public string  LessorLicense     { get; set; } = string.Empty;
    public string  LessorLicAuthority{ get; set; } = string.Empty;
    public string  LessorEmail       { get; set; } = string.Empty;
    public string  LessorPhone       { get; set; } = string.Empty;

    // ── Payment Summary ────────────────────────────────────────────────────
    public decimal TotalPaid         { get; set; }
    public decimal TotalDue          { get; set; }
    public decimal TotalWaived       { get; set; }
    public int     TotalInstallments { get; set; }
    public int     PaidInstallments  { get; set; }
    public int     PendingInstallments { get; set; }
    public decimal? LastPaymentAmount { get; set; }
    public string?  LastPaymentDate  { get; set; }

    // ── Installments (full payment schedule) ──────────────────────────────
    public List<ContractDocInstallment> Installments { get; set; } = new();
}

public class ContractDocRoom
{
    public int    Id          { get; set; }
    public string RoomNo      { get; set; } = string.Empty;
    public string FloorName   { get; set; } = string.Empty;
    public decimal MonthlyPrice { get; set; }
}

public class ContractDocInstallment
{
    public int      Id            { get; set; }
    public int      InstallmentNo { get; set; }
    public decimal  Amount        { get; set; }
    public string   DueDate       { get; set; } = string.Empty;
    public decimal  PaidAmount    { get; set; }
    public decimal  BalanceAmount { get; set; }
    public string?  PaidDate      { get; set; }
    public string   Status        { get; set; } = string.Empty;
    public string   PaymentMode   { get; set; } = string.Empty;
    public string   ChequeNumber  { get; set; } = string.Empty;
    public string   ClearanceDate { get; set; } = string.Empty;
    public string   ReceivedBy    { get; set; } = string.Empty;
    public string   FundPoolName  { get; set; } = string.Empty;
    public string   Description   { get; set; } = string.Empty;
}
