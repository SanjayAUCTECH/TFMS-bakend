using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class LoginRequest
{
    [Required] public string Username { get; set; } = string.Empty;
    [Required] public string Password { get; set; } = string.Empty;
}

public class LoginResponse
{
    public string    Token      { get; set; } = string.Empty;
    public int       UserId     { get; set; }
    public string    UserCode   { get; set; } = string.Empty;
    public string    Name       { get; set; } = string.Empty;
    public string    Username   { get; set; } = string.Empty;
    public string    Role       { get; set; } = string.Empty;
    public bool      IsAdmin    { get; set; }
    public string    MenuAccess { get; set; } = "{}";
    public string    Contact    { get; set; } = string.Empty;
    public string    Email      { get; set; } = string.Empty;
    public string    Source     { get; set; } = string.Empty;
    public int?      SourceId   { get; set; }
    public DateTime? LastLogin  { get; set; }
    public DateTime  ExpiresAt  { get; set; }
}

public class ProfileResponse
{
    public int      Id          { get; set; }
    public string   UserId      { get; set; } = string.Empty;
    public string   Name        { get; set; } = string.Empty;
    public string   Username    { get; set; } = string.Empty;
    public string   Role        { get; set; } = string.Empty;
    public string   Source      { get; set; } = string.Empty;
    public int?     SourceId    { get; set; }
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
    public string  Name    { get; set; } = string.Empty;
    public string  Contact { get; set; } = string.Empty;
    public string? Email   { get; set; }
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword     { get; set; } = string.Empty;
    public string ConfirmPassword { get; set; } = string.Empty;
}

public class RefreshTokenRequest
{
    [Required] public string Token { get; set; } = string.Empty;
}

public class UpdateMenuAccessRequest
{
    [Required] public string MenuAccess { get; set; } = "{}";
}

public class DashboardStatsResponse
{
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
    public List<DashCampOccupancy>     CampOccupancy      { get; set; } = new();
    public List<DashMonthlyCollection> MonthlyCollections { get; set; } = new();
    public List<DashCampRevenue>       CampRevenue        { get; set; } = new();
    public decimal TotalPaidAmount    { get; set; }
    public decimal TotalPendingAmount { get; set; }
    public int     CompletedContracts { get; set; }
}

public class DashCampOccupancy
{
    public string CampName   { get; set; } = string.Empty;
    public int    Occupied   { get; set; }
    public int    Vacant     { get; set; }
    public int    TotalRooms { get; set; }
}

public class DashMonthlyCollection
{
    public string  Month     { get; set; } = string.Empty;
    public decimal Collected { get; set; }
}

public class DashCampRevenue
{
    public string  CampName       { get; set; } = string.Empty;
    public decimal MonthlyRevenue { get; set; }
}

// ── Staff Document Expiry Alert DTOs ──────────────────────────────────────

public class StaffExpiryAlertResponse
{
    /// <summary>Total alert count (expired + expiring soon)</summary>
    public int                       TotalAlerts    { get; set; }
    public int                       ExpiredCount   { get; set; }
    public int                       ExpiringSoon   { get; set; }
    public List<StaffExpiryAlertRow> Alerts         { get; set; } = new();
}

public class StaffExpiryAlertRow
{
    public int     StaffId       { get; set; }
    public string  StaffCode     { get; set; } = string.Empty;
    public string  StaffName     { get; set; } = string.Empty;
    public string  Contact       { get; set; } = string.Empty;
    public string  Designation   { get; set; } = string.Empty;
    public string  DocumentType  { get; set; } = string.Empty;   // "Emirates ID", "Passport", etc.
    public string  ExpiryDate    { get; set; } = string.Empty;   // "yyyy-MM-dd"
    public int     DaysRemaining { get; set; }                   // negative = already expired
    public string  AlertType     { get; set; } = string.Empty;   // "Expired" | "Expiring Soon"
}
