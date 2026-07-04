using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class UserRepository : IUserRepository
{
    private readonly IDbConnectionFactory _factory;
    public UserRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<AppUser> Data, int TotalRecords)> GetAllAsync(UserListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetUsers", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",    request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Role",          (object?)request.Role       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Source",        (object?)request.Source     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<AppUser>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapUser(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<AppUser?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetUserById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapUser(r) : null;
    }

    public async Task<AppUser?> GetByUsernameAsync(string username)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM AppUsers WHERE Username=@Username", conn);
        cmd.Parameters.AddWithValue("@Username", username);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapUser(r) : null;
    }

    public async Task<int> CreateAsync(AppUser user)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateUser", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Name",         user.Name);
        cmd.Parameters.AddWithValue("@Username",     user.Username);
        cmd.Parameters.AddWithValue("@PasswordHash", user.Password);
        cmd.Parameters.AddWithValue("@Role",         user.Role);
        cmd.Parameters.AddWithValue("@Source",       user.Source);
        cmd.Parameters.AddWithValue("@SourceId",     (object?)user.SourceId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Contact",      user.Contact);
        cmd.Parameters.AddWithValue("@Email",        user.Email);
        cmd.Parameters.AddWithValue("@IsAdmin",      user.IsAdmin);
        cmd.Parameters.AddWithValue("@LoginAccess",  user.LoginAccess);
        cmd.Parameters.AddWithValue("@Status",       user.Status);
        cmd.Parameters.AddWithValue("@MenuAccess",   user.MenuAccess);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(AppUser user)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateUser", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",          user.Id);
        cmd.Parameters.AddWithValue("@Name",        user.Name);
        cmd.Parameters.AddWithValue("@Role",        user.Role);
        cmd.Parameters.AddWithValue("@Source",      user.Source);
        cmd.Parameters.AddWithValue("@SourceId",    (object?)user.SourceId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Contact",     user.Contact);
        cmd.Parameters.AddWithValue("@Email",       user.Email);
        cmd.Parameters.AddWithValue("@IsAdmin",     user.IsAdmin);
        cmd.Parameters.AddWithValue("@LoginAccess", user.LoginAccess);
        cmd.Parameters.AddWithValue("@Status",      user.Status);
        cmd.Parameters.AddWithValue("@MenuAccess",  user.MenuAccess);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> UpdatePasswordAsync(int id, string password)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "UPDATE AppUsers SET PasswordHash=@PasswordHash,UpdatedAt=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id",           id);
        cmd.Parameters.AddWithValue("@PasswordHash", password);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> UpdateMenuAccessAsync(int id, string menuAccess)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "UPDATE AppUsers SET MenuAccess=@MenuAccess,UpdatedAt=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id",         id);
        cmd.Parameters.AddWithValue("@MenuAccess", menuAccess);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> UpdateLoginAccessAsync(int id, string loginAccess)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "UPDATE AppUsers SET LoginAccess=@LoginAccess,UpdatedAt=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id",          id);
        cmd.Parameters.AddWithValue("@LoginAccess", loginAccess);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteUser", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM AppUsers WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    public async Task<UserStatsResponse> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                          AS TotalUsers,
                SUM(CASE WHEN Status='Active'   THEN 1 ELSE 0 END) AS ActiveUsers,
                SUM(CASE WHEN Status!='Active'  THEN 1 ELSE 0 END) AS InactiveUsers,
                COUNT(DISTINCT NULLIF(LTRIM(RTRIM(Role)),''))     AS RolesAssigned
            FROM AppUsers", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new UserStatsResponse();
        return new UserStatsResponse
        {
            TotalUsers    = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            ActiveUsers   = r.IsDBNull(1) ? 0 : r.GetInt32(1),
            InactiveUsers = r.IsDBNull(2) ? 0 : r.GetInt32(2),
            RolesAssigned = r.IsDBNull(3) ? 0 : r.GetInt32(3),
        };
    }

    public async Task<bool> UsernameExistsAsync(string username, int? excludeId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = excludeId.HasValue
            ? "SELECT COUNT(1) FROM AppUsers WHERE Username=@Username AND Id<>@ExcludeId"
            : "SELECT COUNT(1) FROM AppUsers WHERE Username=@Username";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Username", username);
        if (excludeId.HasValue) cmd.Parameters.AddWithValue("@ExcludeId", excludeId.Value);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static AppUser MapUser(SqlDataReader r) => new()
    {
        Id           = r.GetInt32(r.GetOrdinal("Id")),
        UserId       = r.GetString(r.GetOrdinal("UserId")),
        Name         = r.GetString(r.GetOrdinal("Name")),
        Username     = r.GetString(r.GetOrdinal("Username")),
        Password     = r.GetString(r.GetOrdinal("PasswordHash")),
        Role         = r.IsDBNull(r.GetOrdinal("Role"))        ? "" : r.GetString(r.GetOrdinal("Role")),
        Source       = r.IsDBNull(r.GetOrdinal("Source"))      ? "" : r.GetString(r.GetOrdinal("Source")),
        SourceId     = r.IsDBNull(r.GetOrdinal("SourceId"))    ? null : r.GetInt32(r.GetOrdinal("SourceId")),
        Contact      = r.IsDBNull(r.GetOrdinal("Contact"))     ? "" : r.GetString(r.GetOrdinal("Contact")),
        Email        = r.IsDBNull(r.GetOrdinal("Email"))       ? "" : r.GetString(r.GetOrdinal("Email")),
        IsAdmin      = r.GetBoolean(r.GetOrdinal("IsAdmin")),
        LoginAccess  = r.GetString(r.GetOrdinal("LoginAccess")),
        Status       = r.GetString(r.GetOrdinal("Status")),
        MenuAccess   = r.IsDBNull(r.GetOrdinal("MenuAccess"))  ? "{}" : r.GetString(r.GetOrdinal("MenuAccess")),
        LastLogin    = r.IsDBNull(r.GetOrdinal("LastLogin"))   ? null : r.GetDateTime(r.GetOrdinal("LastLogin")),
        CreatedAt    = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt    = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
