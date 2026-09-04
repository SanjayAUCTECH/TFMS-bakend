using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class SalonStaffAssignRepository : ISalonStaffAssignRepository
{
    private readonly IDbConnectionFactory _factory;

    public SalonStaffAssignRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── GET ALL ────────────────────────────────────────────────────────────────
    public async Task<(IEnumerable<SalonStaffAssign> Data, int TotalRecords)> GetAllAsync(
        SalonStaffAssignListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonStaffAssign", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SalonId",    (object?)request.SalonId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)request.Status     ?? DBNull.Value);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var list = new List<SalonStaffAssign>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(Map(reader));

        await reader.CloseAsync();
        return (list, totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value);
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<SalonStaffAssign?> GetByIdAsync(int assignId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonStaffAssignById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@AssignId", assignId);

        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<int> CreateAsync(SalonStaffAssign assign)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_CreateSalonStaffAssign", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@SalonId",     assign.SalonId);
        cmd.Parameters.AddWithValue("@StaffId",     assign.StaffId);
        cmd.Parameters.AddWithValue("@Percentage",  assign.Percentage);
        cmd.Parameters.AddWithValue("@Description", (object?)assign.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      assign.Status);
        cmd.Parameters.AddWithValue("@AddedBy",     (object?)assign.AddedBy     ?? DBNull.Value);

        var newIdParam = new SqlParameter("@NewId", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(newIdParam);

        await cmd.ExecuteNonQueryAsync();
        return (int)newIdParam.Value;
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<bool> UpdateAsync(SalonStaffAssign assign)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateSalonStaffAssign", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@AssignId",    assign.AssignId);
        cmd.Parameters.AddWithValue("@SalonId",     assign.SalonId);
        cmd.Parameters.AddWithValue("@StaffId",     assign.StaffId);
        cmd.Parameters.AddWithValue("@Percentage",  assign.Percentage);
        cmd.Parameters.AddWithValue("@Description", (object?)assign.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      assign.Status);
        cmd.Parameters.AddWithValue("@UpdatedBy",   (object?)assign.UpdatedBy   ?? DBNull.Value);

        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // ── SOFT DELETE ────────────────────────────────────────────────────────────
    public async Task<bool> DeleteAsync(int assignId, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteSalonStaffAssign", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@AssignId",  assignId);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy?.ToString() ?? DBNull.Value);

        // SP returns AffectedRows — idempotent, always succeeds
        await using var reader = await cmd.ExecuteReaderAsync();
        return true;
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static SalonStaffAssign Map(SqlDataReader r)
    {
        int ordDesc      = r.GetOrdinal("Description");
        int ordUpdatedAt = r.GetOrdinal("UpdatedAt");

        return new SalonStaffAssign
        {
            AssignId    = r.GetInt32(r.GetOrdinal("AssignId")),
            SalonId     = r.GetInt32(r.GetOrdinal("SalonId")),
            SalonName   = r.GetString(r.GetOrdinal("SalonName")),
            StaffId     = r.GetInt32(r.GetOrdinal("StaffId")),
            StaffName   = r.GetString(r.GetOrdinal("StaffName")),
            Percentage  = r.GetDecimal(r.GetOrdinal("Percentage")),
            Description = r.IsDBNull(ordDesc)      ? null : r.GetString(ordDesc),
            Status      = r.GetString(r.GetOrdinal("Status")),
            CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt   = r.IsDBNull(ordUpdatedAt) ? null : r.GetDateTime(ordUpdatedAt),
        };
    }
}
