using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class DashboardRepository : IDashboardRepository
{
    private readonly IDbConnectionFactory _factory;
    public DashboardRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<DashboardStatsResponse> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetDashboardStats", conn) { CommandType = CommandType.StoredProcedure };
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new DashboardStatsResponse();
        return new DashboardStatsResponse
        {
            TotalCamps               = r.IsDBNull(r.GetOrdinal("TotalCamps"))               ? 0 : r.GetInt32(r.GetOrdinal("TotalCamps")),
            TotalRooms               = r.IsDBNull(r.GetOrdinal("TotalRooms"))               ? 0 : r.GetInt32(r.GetOrdinal("TotalRooms")),
            OccupiedRooms            = r.IsDBNull(r.GetOrdinal("OccupiedRooms"))            ? 0 : r.GetInt32(r.GetOrdinal("OccupiedRooms")),
            VacantRooms              = r.IsDBNull(r.GetOrdinal("VacantRooms"))              ? 0 : r.GetInt32(r.GetOrdinal("VacantRooms")),
            TotalTenants             = r.IsDBNull(r.GetOrdinal("TotalTenants"))             ? 0 : r.GetInt32(r.GetOrdinal("TotalTenants")),
            ActiveTenants            = r.IsDBNull(r.GetOrdinal("ActiveTenants"))            ? 0 : r.GetInt32(r.GetOrdinal("ActiveTenants")),
            TotalPartners            = r.IsDBNull(r.GetOrdinal("TotalPartners"))            ? 0 : r.GetInt32(r.GetOrdinal("TotalPartners")),
            ActiveContracts          = r.IsDBNull(r.GetOrdinal("ActiveContracts"))          ? 0 : r.GetInt32(r.GetOrdinal("ActiveContracts")),
            TotalDueThisMonth        = r.IsDBNull(r.GetOrdinal("TotalDueThisMonth"))        ? 0 : r.GetDecimal(r.GetOrdinal("TotalDueThisMonth")),
            TotalCollectedThisMonth  = r.IsDBNull(r.GetOrdinal("TotalCollectedThisMonth"))  ? 0 : r.GetDecimal(r.GetOrdinal("TotalCollectedThisMonth")),
            OutstandingBalance       = r.IsDBNull(r.GetOrdinal("OutstandingBalance"))       ? 0 : r.GetDecimal(r.GetOrdinal("OutstandingBalance")),
            OverduePayments          = r.IsDBNull(r.GetOrdinal("OverduePayments"))          ? 0 : r.GetInt32(r.GetOrdinal("OverduePayments")),
        };
    }

    public async Task<AppUser?> GetUserByUsernameAsync(string username)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM AppUsers WHERE Username=@Username AND LoginAccess='enabled' AND Status='Active'", conn);
        cmd.Parameters.AddWithValue("@Username", username);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;
        return new AppUser
        {
            Id           = r.GetInt32(r.GetOrdinal("Id")),
            UserId       = r.GetString(r.GetOrdinal("UserId")),
            Name         = r.GetString(r.GetOrdinal("Name")),
            Username     = r.GetString(r.GetOrdinal("Username")),
            PasswordHash = r.GetString(r.GetOrdinal("PasswordHash")),
            Role         = r.IsDBNull(r.GetOrdinal("Role"))   ? "" : r.GetString(r.GetOrdinal("Role")),
            IsAdmin      = r.GetBoolean(r.GetOrdinal("IsAdmin")),
            MenuAccess   = r.IsDBNull(r.GetOrdinal("MenuAccess")) ? "{}" : r.GetString(r.GetOrdinal("MenuAccess")),
            Status       = r.GetString(r.GetOrdinal("Status")),
            LoginAccess  = r.GetString(r.GetOrdinal("LoginAccess")),
        };
    }

    public async Task UpdateLastLoginAsync(int userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("UPDATE AppUsers SET LastLogin=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", userId);
        await cmd.ExecuteNonQueryAsync();
    }
}
