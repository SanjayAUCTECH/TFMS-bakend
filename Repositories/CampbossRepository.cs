using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class CampbossRepository : ICampbossRepository
{
    private readonly IDbConnectionFactory _factory;
    public CampbossRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Campboss> Data, int TotalRecords)> GetAllAsync(CampbossListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampbosses", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",    request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Campboss>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Campboss?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampbossById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(Campboss cb)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateCampboss", conn) { CommandType = CommandType.StoredProcedure };
        AddParams(cmd, cb);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)cb.AddedBy ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Campboss cb)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateCampboss", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", cb.Id);
        AddParams(cmd, cb);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)cb.UpdatedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteCampboss", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> UsernameExistsAsync(string username, int? excludeId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = excludeId.HasValue
            ? "SELECT COUNT(1) FROM Campbosses WHERE Username=@Username AND Id<>@ExcludeId AND IsDeleted=0"
            : "SELECT COUNT(1) FROM Campbosses WHERE Username=@Username AND IsDeleted=0";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Username", username);
        if (excludeId.HasValue) cmd.Parameters.AddWithValue("@ExcludeId", excludeId.Value);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static void AddParams(SqlCommand cmd, Campboss cb)
    {
        cmd.Parameters.AddWithValue("@Name",        cb.Name);
        cmd.Parameters.AddWithValue("@Contact",     (object?)cb.Contact     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Email",       (object?)cb.Email       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Address",     (object?)cb.Address     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Username",    (object?)cb.Username    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Password",    (object?)cb.Password    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@LoginAccess", cb.LoginAccess);
        cmd.Parameters.AddWithValue("@Status",      cb.Status);
        cmd.Parameters.AddWithValue("@Remarks",     (object?)cb.Remarks     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@EmiratesId",  (object?)cb.EmiratesId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PassportNo",  (object?)cb.PassportNo  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Nationality", (object?)cb.Nationality ?? DBNull.Value);
    }

    private static Campboss Map(SqlDataReader r) => new()
    {
        Id          = r.GetInt32(r.GetOrdinal("Id")),
        CampbossId  = S(r, "CampbossId"),
        Name        = r.GetString(r.GetOrdinal("Name")),
        Contact     = S(r, "Contact"),
        Email       = S(r, "Email"),
        Address     = S(r, "Address"),
        Username    = S(r, "Username"),
        LoginAccess = S(r, "LoginAccess") ?? "enabled",
        Status      = r.GetString(r.GetOrdinal("Status")),
        Remarks     = S(r, "Remarks"),
        EmiratesId  = S(r, "EmiratesId"),
        PassportNo  = S(r, "PassportNo"),
        Nationality = S(r, "Nationality"),
        CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt   = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static string? S(SqlDataReader r, string col)
    { try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? null : r.GetString(o); } catch { return null; } }
}
