using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class StaffRepository : IStaffRepository
{
    private readonly IDbConnectionFactory _factory;
    public StaffRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Staff> Data, int TotalRecords)> GetAllAsync(StaffListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",    request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Staff>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapStaff(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Staff?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetStaffById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapStaff(r) : null;
    }

    public async Task<Staff?> GetByUsernameAsync(string username)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM Staff WHERE Username=@Username", conn);
        cmd.Parameters.AddWithValue("@Username", username);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapStaff(r) : null;
    }

    public async Task<int> CreateAsync(Staff staff)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Name",        staff.Name);
        cmd.Parameters.AddWithValue("@Contact",     staff.Contact);
        cmd.Parameters.AddWithValue("@Email",       staff.Email);
        cmd.Parameters.AddWithValue("@Address",     staff.Address);
        cmd.Parameters.AddWithValue("@Username",    string.IsNullOrWhiteSpace(staff.Username) ? (object)DBNull.Value : staff.Username);
        cmd.Parameters.AddWithValue("@Password",    staff.Password);
        cmd.Parameters.AddWithValue("@LoginAccess", staff.LoginAccess);
        cmd.Parameters.AddWithValue("@Status",      staff.Status);
        cmd.Parameters.AddWithValue("@Remarks",     staff.Remarks);
        cmd.Parameters.AddWithValue("@EmiratesId",  staff.EmiratesId);
        cmd.Parameters.AddWithValue("@PassportNo",  staff.PassportNo);
        cmd.Parameters.AddWithValue("@Nationality", staff.Nationality);
        cmd.Parameters.AddWithValue("@JobTitle",    staff.JobTitle);
        cmd.Parameters.AddWithValue("@MoveInDate",  (object?)staff.MoveInDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@VisaExpiry",  (object?)staff.VisaExpiry ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Staff staff)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",          staff.Id);
        cmd.Parameters.AddWithValue("@Name",        staff.Name);
        cmd.Parameters.AddWithValue("@Contact",     staff.Contact);
        cmd.Parameters.AddWithValue("@Email",       staff.Email);
        cmd.Parameters.AddWithValue("@Address",     staff.Address);
        cmd.Parameters.AddWithValue("@Username",    string.IsNullOrWhiteSpace(staff.Username) ? (object)DBNull.Value : staff.Username);
        cmd.Parameters.AddWithValue("@Password",    (object?)staff.Password ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@LoginAccess", staff.LoginAccess);
        cmd.Parameters.AddWithValue("@Status",      staff.Status);
        cmd.Parameters.AddWithValue("@Remarks",     staff.Remarks);
        cmd.Parameters.AddWithValue("@EmiratesId",  staff.EmiratesId);
        cmd.Parameters.AddWithValue("@PassportNo",  staff.PassportNo);
        cmd.Parameters.AddWithValue("@Nationality", staff.Nationality);
        cmd.Parameters.AddWithValue("@JobTitle",    staff.JobTitle);
        cmd.Parameters.AddWithValue("@MoveInDate",  (object?)staff.MoveInDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@VisaExpiry",  (object?)staff.VisaExpiry ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                                          AS total,
                SUM(CASE WHEN Status='Active'        THEN 1 ELSE 0 END)          AS active,
                SUM(CASE WHEN Status='Inactive'      THEN 1 ELSE 0 END)          AS inactive,
                SUM(CASE WHEN LoginAccess='enabled'  THEN 1 ELSE 0 END)          AS withAccess
            FROM Staff", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { total=0, active=0, inactive=0, withAccess=0 };
        return new {
            total      = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            active     = r.IsDBNull(1) ? 0 : r.GetInt32(1),
            inactive   = r.IsDBNull(2) ? 0 : r.GetInt32(2),
            withAccess = r.IsDBNull(3) ? 0 : r.GetInt32(3),
        };
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Staff WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    public async Task<bool> UsernameExistsAsync(string username, int? excludeId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = excludeId.HasValue
            ? "SELECT COUNT(1) FROM Staff WHERE Username=@Username AND Id<>@ExcludeId"
            : "SELECT COUNT(1) FROM Staff WHERE Username=@Username";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Username", username);
        if (excludeId.HasValue) cmd.Parameters.AddWithValue("@ExcludeId", excludeId.Value);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static Staff MapStaff(SqlDataReader r) => new()
    {
        Id          = r.GetInt32(r.GetOrdinal("Id")),
        StaffId     = r.GetString(r.GetOrdinal("StaffId")),
        Name        = r.GetString(r.GetOrdinal("Name")),
        Role        = r.IsDBNull(r.GetOrdinal("Role"))        ? "Staff" : r.GetString(r.GetOrdinal("Role")),
        Contact     = r.IsDBNull(r.GetOrdinal("Contact"))     ? "" : r.GetString(r.GetOrdinal("Contact")),
        Email       = r.IsDBNull(r.GetOrdinal("Email"))       ? "" : r.GetString(r.GetOrdinal("Email")),
        Address     = r.IsDBNull(r.GetOrdinal("Address"))     ? "" : r.GetString(r.GetOrdinal("Address")),
        Username    = r.IsDBNull(r.GetOrdinal("Username"))    ? "" : r.GetString(r.GetOrdinal("Username")),
        Password    = r.IsDBNull(r.GetOrdinal("Password"))    ? "" : r.GetString(r.GetOrdinal("Password")),
        LoginAccess = r.IsDBNull(r.GetOrdinal("LoginAccess")) ? "enabled" : r.GetString(r.GetOrdinal("LoginAccess")),
        Status      = r.GetString(r.GetOrdinal("Status")),
        Remarks     = r.IsDBNull(r.GetOrdinal("Remarks"))     ? "" : r.GetString(r.GetOrdinal("Remarks")),
        EmiratesId  = SafeStr(r, "EmiratesId"),
        PassportNo  = SafeStr(r, "PassportNo"),
        Nationality = SafeStr(r, "Nationality"),
        JobTitle    = SafeStr(r, "JobTitle"),
        MoveInDate  = SafeDate(r, "MoveInDate"),
        VisaExpiry  = SafeDate(r, "VisaExpiry"),
        CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt   = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static string SafeStr(SqlDataReader r, string col)
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? "" : r.GetString(o); } catch { return ""; }
    }

    private static DateTime? SafeDate(SqlDataReader r, string col)
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? null : r.GetDateTime(o); } catch { return null; }
    }
}
