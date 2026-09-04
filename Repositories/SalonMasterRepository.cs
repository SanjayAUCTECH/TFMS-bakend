using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class SalonMasterRepository : ISalonMasterRepository
{
    private readonly IDbConnectionFactory _factory;

    public SalonMasterRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── GET ALL (paginated) ────────────────────────────────────────────────────
    public async Task<(IEnumerable<SalonMaster> Data, int TotalRecords)> GetAllAsync(SalonMasterListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@PageNumber",  request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",    request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      (object?)request.Status     ?? DBNull.Value);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var list = new List<SalonMaster>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(Map(reader));

        await reader.CloseAsync();

        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        return (list, total);
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<SalonMaster?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonMasterById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<int> CreateAsync(SalonMaster salon)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_CreateSalonMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Name",           salon.Name);
        cmd.Parameters.AddWithValue("@Address",        salon.Address);
        cmd.Parameters.AddWithValue("@Contact",        salon.Contact);
        cmd.Parameters.AddWithValue("@Description",    (object?)salon.Description    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ThumbnailImage", (object?)salon.ThumbnailImage ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",         salon.Status);
        cmd.Parameters.AddWithValue("@AddedBy",        (object?)salon.AddedBy?.ToString() ?? DBNull.Value);

        var newIdParam = new SqlParameter("@NewId", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(newIdParam);

        await cmd.ExecuteNonQueryAsync();
        return (int)newIdParam.Value;
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<bool> UpdateAsync(SalonMaster salon)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateSalonMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id",             salon.Id);
        cmd.Parameters.AddWithValue("@Name",           salon.Name);
        cmd.Parameters.AddWithValue("@Address",        salon.Address);
        cmd.Parameters.AddWithValue("@Contact",        salon.Contact);
        cmd.Parameters.AddWithValue("@Description",    (object?)salon.Description    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ThumbnailImage", (object?)salon.ThumbnailImage ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",         salon.Status);
        cmd.Parameters.AddWithValue("@UpdatedBy",      (object?)salon.UpdatedBy?.ToString() ?? DBNull.Value);

        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // ── SOFT DELETE ────────────────────────────────────────────────────────────
    public async Task<bool> DeleteAsync(int id, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteSalonMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy?.ToString() ?? DBNull.Value);

        // SP returns AffectedRows — we treat any execution as success
        await using var reader = await cmd.ExecuteReaderAsync();
        return true;
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static SalonMaster Map(SqlDataReader r)
    {
        int ordName      = r.GetOrdinal("Name");
        int ordAddress   = r.GetOrdinal("Address");
        int ordContact   = r.GetOrdinal("Contact");
        int ordDesc      = r.GetOrdinal("Description");
        int ordThumb     = r.GetOrdinal("ThumbnailImage");
        int ordStatus    = r.GetOrdinal("Status");
        int ordUpdatedAt = r.GetOrdinal("UpdatedAt");

        return new SalonMaster
        {
            Id             = r.GetInt32(r.GetOrdinal("Id")),
            Name           = r.IsDBNull(ordName)      ? null : r.GetString(ordName),
            Address        = r.IsDBNull(ordAddress)   ? null : r.GetString(ordAddress),
            Contact        = r.IsDBNull(ordContact)   ? null : r.GetString(ordContact),
            Description    = r.IsDBNull(ordDesc)      ? null : r.GetString(ordDesc),
            ThumbnailImage = r.IsDBNull(ordThumb)     ? null : r.GetString(ordThumb),
            Status         = r.IsDBNull(ordStatus)    ? null : r.GetString(ordStatus),
            CreatedAt      = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt      = r.IsDBNull(ordUpdatedAt) ? null : r.GetDateTime(ordUpdatedAt),
        };
    }
}
