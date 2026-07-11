using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class OwnerRepository : IOwnerRepository
{
    private readonly IDbConnectionFactory _factory;
    public OwnerRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Owner> Data, int TotalRecords)> GetAllAsync(OwnerListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwners", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Id",            (object?)request.Id        ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var list = new List<Owner>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Owner?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(Owner o)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateOwner", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Name",    o.Name);
        cmd.Parameters.AddWithValue("@Contact", o.Contact);
        cmd.Parameters.AddWithValue("@Email",   o.Email);
        cmd.Parameters.AddWithValue("@Status",  o.Status);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Owner o)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateOwner", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",      o.Id);
        cmd.Parameters.AddWithValue("@Name",    o.Name);
        cmd.Parameters.AddWithValue("@Contact", o.Contact);
        cmd.Parameters.AddWithValue("@Email",   o.Email);
        cmd.Parameters.AddWithValue("@Status",  o.Status);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOwner", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Owners WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static Owner Map(SqlDataReader r) => new()
    {
        Id        = r.GetInt32(r.GetOrdinal("Id")),
        Code      = r.GetString(r.GetOrdinal("Code")),
        Name      = r.GetString(r.GetOrdinal("Name")),
        Contact   = r.IsDBNull(r.GetOrdinal("Contact")) ? "" : r.GetString(r.GetOrdinal("Contact")),
        Email     = r.IsDBNull(r.GetOrdinal("Email"))   ? "" : r.GetString(r.GetOrdinal("Email")),
        Status    = r.GetString(r.GetOrdinal("Status")),
        CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
