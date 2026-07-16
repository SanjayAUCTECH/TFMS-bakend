using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class OtherPersonRepository : IOtherPersonRepository
{
    private readonly IDbConnectionFactory _factory;
    public OtherPersonRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<OtherPerson> Data, int TotalRecords)> GetAllAsync(OtherPersonListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOtherPersons", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Designation",   (object?)request.Designation   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Id",            (object?)request.Id            ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<OtherPerson>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<OtherPerson?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOtherPersonById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(OtherPerson op)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateOtherPerson", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Designation", op.Designation);
        cmd.Parameters.AddWithValue("@Name",        op.Name);
        cmd.Parameters.AddWithValue("@Mobile",      op.Mobile);
        cmd.Parameters.AddWithValue("@Email",       op.Email);
        cmd.Parameters.AddWithValue("@Address",     op.Address);
        cmd.Parameters.AddWithValue("@City",        op.City);
        cmd.Parameters.AddWithValue("@State",       op.State);
        cmd.Parameters.AddWithValue("@Pincode",     op.Pincode);
        cmd.Parameters.AddWithValue("@Remarks",     op.Remarks);
        cmd.Parameters.AddWithValue("@Status",      op.Status);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(OtherPerson op)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateOtherPerson", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",          op.Id);
        cmd.Parameters.AddWithValue("@Designation", op.Designation);
        cmd.Parameters.AddWithValue("@Name",        op.Name);
        cmd.Parameters.AddWithValue("@Mobile",      op.Mobile);
        cmd.Parameters.AddWithValue("@Email",       op.Email);
        cmd.Parameters.AddWithValue("@Address",     op.Address);
        cmd.Parameters.AddWithValue("@City",        op.City);
        cmd.Parameters.AddWithValue("@State",       op.State);
        cmd.Parameters.AddWithValue("@Pincode",     op.Pincode);
        cmd.Parameters.AddWithValue("@Remarks",     op.Remarks);
        cmd.Parameters.AddWithValue("@Status",      op.Status);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOtherPerson", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    private static OtherPerson Map(SqlDataReader r) => new()
    {
        Id          = r.GetInt32(r.GetOrdinal("Id")),
        Code        = r.GetString(r.GetOrdinal("Code")),
        Designation = r.GetString(r.GetOrdinal("Designation")),
        Name        = r.GetString(r.GetOrdinal("Name")),
        Mobile      = r.IsDBNull(r.GetOrdinal("Mobile"))  ? "" : r.GetString(r.GetOrdinal("Mobile")),
        Email       = r.IsDBNull(r.GetOrdinal("Email"))   ? "" : r.GetString(r.GetOrdinal("Email")),
        Address     = r.IsDBNull(r.GetOrdinal("Address")) ? "" : r.GetString(r.GetOrdinal("Address")),
        City        = r.IsDBNull(r.GetOrdinal("City"))    ? "" : r.GetString(r.GetOrdinal("City")),
        State       = r.IsDBNull(r.GetOrdinal("State"))   ? "" : r.GetString(r.GetOrdinal("State")),
        Pincode     = r.IsDBNull(r.GetOrdinal("Pincode")) ? "" : r.GetString(r.GetOrdinal("Pincode")),
        Remarks     = r.IsDBNull(r.GetOrdinal("Remarks")) ? "" : r.GetString(r.GetOrdinal("Remarks")),
        Status      = r.GetString(r.GetOrdinal("Status")),
        CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt   = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
