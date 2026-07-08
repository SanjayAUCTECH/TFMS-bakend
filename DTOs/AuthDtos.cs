using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

// ── Login ─────────────────────────────────────────────────────────────────────
public class LoginRequest
{
    [Required] public string Username { get; set; } = string.Empty;
    [Required] public string Password { get; set; } = string.Empty;
}

public class LoginResponse
{
    public string   Token      { get; set; } = string.Empty;
    public int      UserId     { get; set; }
    public string   UserCode   { get; set; } = string.Empty;
    public string   Name       { get; set; } = string.Empty;
    public string   Username   { get; set; } = string.Empty;
    public string   Role       { get; set; } = string.Empty;
    public bool     IsAdmin    { get; set; }
    public string   MenuAccess { get; set; } = "{}";
    public string   Contact    { get; set; } = string.Empty;
    public string   Email      { get; set; } = string.Empty;
    public string   Source     { get; set; } = string.Empty;
    public DateTime? LastLogin  { get; set; }
    public DateTime ExpiresAt  { get; set; }
}

// ── Profile ───────────────────────────────────────────────────────────────────
public class ProfileResponse
{
    public int      Id          { get; set; }
    public string   UserId      { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Username    { get; set; } = string.Empty;
    public string   Role        { get; set; } = string.Empty;
    public string   Source      { get; set; } = string.Empty;
    public string   Contact     { get; set; } = string.Empty;
    public string   Email       { get; set; } = string.Empty;
    public bool     IsAdmin     { get; set; }
    public string   LoginAccess { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public string   MenuAccess  { get; set; } = "{}";
    public DateTime? LastLogin  { get; set; }
    public DateTime CreatedAt   { get; set; }
}

public class UpdateProfileRequest
{
    [MaxLength(200)] public string  Name    { get; set; } = string.Empty;
    [MaxLength(20)]  public string  Contact { get; set; } = string.Empty;
    [MaxLength(150)] public string? Email   { get; set; }
}

// ── Password ──────────────────────────────────────────────────────────────────
public class ChangePasswordRequest
{
    public string CurrentPassword  { get; set; } = string.Empty;
    public string NewPassword      { get; set; } = string.Empty;
    public string ConfirmPassword  { get; set; } = string.Empty;
}

// ── Refresh Token ─────────────────────────────────────────────────────────────
public class RefreshTokenRequest
{
    [Required] public string Token { get; set; } = string.Empty;
}

// ── Menu Access ───────────────────────────────────────────────────────────────
public class UpdateMenuAccessRequest
{
    [Required] public string MenuAccess { get; set; } = "{}";
}

// ── Dashboard Stats ───────────────────────────────────────────────────────────
public class DashboardStatsResponse
{
    // ── KPI Cards ──────────────────────────────────────────────────────────
    public int     TotalCamps               { get; set; }
    public int     TotalRooms               { get; set; }
    public int     OccupiedRooms            { get; set; }
    public int     VacantRooms              { get; set; }
    public int     TotalTenants             { get; set; }
    public int     ActiveTenants            { get; set; }
    public int     TotalPartners            { get; set; }
    public int     ActiveContracts          { get; set; }
    public decimal TotalDueThisMonth        { get; set; }
    public decimal TotalCollectedThisMonth  { get; set; }
    public decimal OutstandingBalance       { get; set; }
    public int     OverduePayments          { get; set; }

    // ── Chart Data ────────────────────────────────────────────────────────
    // occupancyChart — Bar: Occupied vs Vacant per camp
    public List<DashCampOccupancy>    CampOccupancy     { get; set; } = new();
    // collectionChart — Line: monthly collection amounts Jan-Dec
    public List<DashMonthlyCollection> MonthlyCollections { get; set; } = new();
    // revenueChart — Bar: monthly revenue potential per camp
    public List<DashCampRevenue>      CampRevenue       { get; set; } = new();
    // dashPaymentPieChart — Doughnut: total paid vs total pending
    public decimal TotalPaidAmount    { get; set; }
    public decimal TotalPendingAmount { get; set; }
    // dashContractChart — Pie: active vs completed contracts
    public int     CompletedContracts { get; set; }
}

public class DashCampOccupancy
{
    public string CampName    { get; set; } = string.Empty;
    public int    Occupied    { get; set; }
    public int    Vacant      { get; set; }
    public int    TotalRooms  { get; set; }
}

public class DashMonthlyCollection
{
    public string  Month      { get; set; } = string.Empty;  // "Jan", "Feb" ...
    public decimal Collected  { get; set; }
}

public class DashCampRevenue
{
    public string  CampName      { get; set; } = string.Empty;
    public decimal MonthlyRevenue { get; set; }  // sum of monthlyPrice for occupied rooms
}
