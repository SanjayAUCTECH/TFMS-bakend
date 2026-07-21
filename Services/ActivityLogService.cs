using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

// ── Activity Types ──────────────────────────────────────────────────────────
public static class ActivityType
{
    public const string Login   = "LOGIN";
    public const string Logout  = "LOGOUT";
    public const string Insert  = "INSERT";
    public const string Update  = "UPDATE";
    public const string Delete  = "DELETE";
    public const string View    = "VIEW";
    public const string Error   = "ERROR";
    public const string Export  = "EXPORT";
    public const string Approve = "APPROVE";
}

// ── Modules ─────────────────────────────────────────────────────────────────
public static class ActivityModule
{
    public const string Auth             = "Auth";
    public const string Contracts        = "Contracts";
    public const string ContractRenewals = "ContractRenewals";
    public const string ContractCancel   = "ContractCancellation";
    public const string Payments         = "Payments";
    public const string SecurityDeposit  = "SecurityDeposit";
    public const string Incomes          = "Incomes";
    public const string Expenses         = "Expenses";
    public const string Tenants          = "Tenants";
    public const string Camps            = "Camps";
    public const string Rooms            = "Rooms";
    public const string Partners         = "Partners";
    public const string FundPools        = "FundPools";
    public const string Users            = "Users";
    public const string Reports          = "Reports";
    public const string Waivers          = "Waivers";
}

// ── IActivityLogService ──────────────────────────────────────────────────────
public interface IActivityLogService
{
    Task LogAsync(
        string activityType,
        string module,
        string action,
        string entityId      = "",
        string entityType    = "",
        object? oldValues    = null,
        object? newValues    = null,
        int?    userId       = null,
        string  userName     = "",
        string  userRole     = "",
        string  ipAddress    = "",
        string  userAgent    = "",
        string  status       = "Success",
        string? errorMessage = null
    );
}

// ── ActivityLogService ───────────────────────────────────────────────────────
public class ActivityLogService : IActivityLogService
{
    private readonly IDbConnectionFactory _factory;

    public ActivityLogService(IDbConnectionFactory factory) => _factory = factory;

    public async Task LogAsync(
        string activityType,
        string module,
        string action,
        string entityId      = "",
        string entityType    = "",
        object? oldValues    = null,
        object? newValues    = null,
        int?    userId       = null,
        string  userName     = "",
        string  userRole     = "",
        string  ipAddress    = "",
        string  userAgent    = "",
        string  status       = "Success",
        string? errorMessage = null)
    {
        try
        {
            await using var conn = _factory.CreateConnection();
            await conn.OpenAsync();

            await using var cmd = new SqlCommand("sp_LogActivity", conn)
            {
                CommandType = CommandType.StoredProcedure
            };

            cmd.Parameters.AddWithValue("@ActivityType",  activityType);
            cmd.Parameters.AddWithValue("@Module",        module);
            cmd.Parameters.AddWithValue("@Action",        action);
            cmd.Parameters.AddWithValue("@EntityId",      entityId);
            cmd.Parameters.AddWithValue("@EntityType",    entityType);
            cmd.Parameters.AddWithValue("@OldValues",     oldValues != null ? JsonSerializer.Serialize(oldValues) : (object)DBNull.Value);
            cmd.Parameters.AddWithValue("@NewValues",     newValues != null ? JsonSerializer.Serialize(newValues) : (object)DBNull.Value);
            cmd.Parameters.AddWithValue("@UserId",        (object?)userId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@UserName",      userName);
            cmd.Parameters.AddWithValue("@UserRole",      userRole);
            cmd.Parameters.AddWithValue("@IpAddress",     ipAddress);
            cmd.Parameters.AddWithValue("@UserAgent",     userAgent);
            cmd.Parameters.AddWithValue("@Status",        status);
            cmd.Parameters.AddWithValue("@ErrorMessage",  (object?)errorMessage ?? DBNull.Value);

            var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
            cmd.Parameters.Add(newId);

            await cmd.ExecuteNonQueryAsync();
        }
        catch
        {
            // Log failure should NEVER crash the main request
            // Silently ignore if logging fails
        }
    }
}
