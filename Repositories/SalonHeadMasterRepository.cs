using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class SalonHeadMasterRepository : ISalonHeadMasterRepository
{
    private readonly IDbConnectionFactory _factory;

    public SalonHeadMasterRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── GET ALL (paginated) ────────────────────────────────────────────────────
    public async Task<(IEnumerable<SalonHeadMaster> Data, int TotalRecords)> GetAllAsync(
        SalonHeadMasterListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonHeadMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@HeadType",   (object?)request.HeadType   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)request.Status     ?? DBNull.Value);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var list = new List<SalonHeadMaster>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(Map(reader));

        await reader.CloseAsync();

        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        return (list, total);
    }

    // ── GET ALL ACTIVE (dropdown) ──────────────────────────────────────────────
    public async Task<IEnumerable<SalonHeadMaster>> GetAllActiveAsync(string? headType = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonHeadMasterActive", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@HeadType", (object?)headType ?? DBNull.Value);

        var list = new List<SalonHeadMaster>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(Map(reader));

        return list;
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<SalonHeadMaster?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonHeadMasterById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<int> CreateAsync(SalonHeadMaster head)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_CreateSalonHeadMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@HeadType", head.HeadType);
        cmd.Parameters.AddWithValue("@HeadName", head.HeadName);
        cmd.Parameters.AddWithValue("@Status",   head.Status);
        cmd.Parameters.AddWithValue("@AddedBy",  (object?)head.AddedBy ?? DBNull.Value);

        var newIdParam = new SqlParameter("@NewId", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(newIdParam);

        await cmd.ExecuteNonQueryAsync();
        return (int)newIdParam.Value;
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<bool> UpdateAsync(SalonHeadMaster head)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateSalonHeadMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id",        head.Id);
        cmd.Parameters.AddWithValue("@HeadType",  head.HeadType);
        cmd.Parameters.AddWithValue("@HeadName",  head.HeadName);
        cmd.Parameters.AddWithValue("@Status",    head.Status);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)head.UpdatedBy ?? DBNull.Value);

        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // ── SOFT DELETE ────────────────────────────────────────────────────────────
    public async Task<bool> DeleteAsync(int id, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteSalonHeadMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);

        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static SalonHeadMaster Map(SqlDataReader r)
    {
        int ordUpdatedAt = r.GetOrdinal("UpdatedAt");

        return new SalonHeadMaster
        {
            Id        = r.GetInt32(r.GetOrdinal("Id")),
            HeadType  = r.GetString(r.GetOrdinal("HeadType")),
            HeadName  = r.GetString(r.GetOrdinal("HeadName")),
            Status    = r.GetString(r.GetOrdinal("Status")),
            CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt = r.IsDBNull(ordUpdatedAt) ? null : r.GetDateTime(ordUpdatedAt),
        };
    }
}
