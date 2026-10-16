using System.Data;
using Microsoft.Data.SqlClient;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class AlertTimeRepository : IAlertTimeRepository
{
    private readonly IDbConnectionFactory _factory;

    public AlertTimeRepository(IDbConnectionFactory factory)
    {
        _factory = factory;
    }

    // ── Get All Alert Times (Paginated) ───────────────────────────
    public async Task<(IEnumerable<AlertTimeResponse> Data, int Total)> GetAllAsync(AlertTimeListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetAlertTimes", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status", (object?)request.Status ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SortBy", request.SortBy ?? "Id");
        cmd.Parameters.AddWithValue("@SortOrder", "ASC");

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var list = new List<AlertTimeResponse>();

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new AlertTimeResponse
            {
                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                AlertName = reader.GetString(reader.GetOrdinal("AlertName")),
                Days = reader.GetInt32(reader.GetOrdinal("Days")),
                Status = reader.GetString(reader.GetOrdinal("Status")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
                AddedBy = reader.IsDBNull(reader.GetOrdinal("AddedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("AddedBy")),
                UpdatedBy = reader.IsDBNull(reader.GetOrdinal("UpdatedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("UpdatedBy"))
            });
        }

        await reader.CloseAsync();
        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;

        return (list, total);
    }

    // ── Get Alert Time By ID ──────────────────────────────────────
    public async Task<AlertTimeResponse?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetAlertTimeById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new AlertTimeResponse
            {
                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                AlertName = reader.GetString(reader.GetOrdinal("AlertName")),
                Days = reader.GetInt32(reader.GetOrdinal("Days")),
                Status = reader.GetString(reader.GetOrdinal("Status")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
                AddedBy = reader.IsDBNull(reader.GetOrdinal("AddedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("AddedBy")),
                UpdatedBy = reader.IsDBNull(reader.GetOrdinal("UpdatedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("UpdatedBy"))
            };
        }

        return null;
    }

    // ── Create Alert Time ─────────────────────────────────────────
    public async Task<AlertTimeResponse?> CreateAsync(CreateAlertTimeRequest request, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_CreateAlertTime", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@AlertName", request.AlertName);
        cmd.Parameters.AddWithValue("@Days", request.Days);
        cmd.Parameters.AddWithValue("@Status", request.Status);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)userId ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            // Check for error
            var id = reader.GetInt32(reader.GetOrdinal("Id"));
            if (id == -1)
            {
                return null; // Duplicate alert name
            }

            return new AlertTimeResponse
            {
                Id = id,
                AlertName = reader.GetString(reader.GetOrdinal("AlertName")),
                Days = reader.GetInt32(reader.GetOrdinal("Days")),
                Status = reader.GetString(reader.GetOrdinal("Status")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
                AddedBy = reader.IsDBNull(reader.GetOrdinal("AddedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("AddedBy")),
                UpdatedBy = reader.IsDBNull(reader.GetOrdinal("UpdatedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("UpdatedBy"))
            };
        }

        return null;
    }

    // ── Update Alert Time ─────────────────────────────────────────
    public async Task<AlertTimeResponse?> UpdateAsync(int id, UpdateAlertTimeRequest request, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateAlertTime", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@AlertName", request.AlertName);
        cmd.Parameters.AddWithValue("@Days", request.Days);
        cmd.Parameters.AddWithValue("@Status", request.Status);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)userId ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            // Check for error
            var resultId = reader.GetInt32(reader.GetOrdinal("Id"));
            if (resultId == -1)
            {
                return null; // Not found or duplicate
            }

            return new AlertTimeResponse
            {
                Id = resultId,
                AlertName = reader.GetString(reader.GetOrdinal("AlertName")),
                Days = reader.GetInt32(reader.GetOrdinal("Days")),
                Status = reader.GetString(reader.GetOrdinal("Status")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
                AddedBy = reader.IsDBNull(reader.GetOrdinal("AddedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("AddedBy")),
                UpdatedBy = reader.IsDBNull(reader.GetOrdinal("UpdatedBy")) 
                    ? null : reader.GetInt32(reader.GetOrdinal("UpdatedBy"))
            };
        }

        return null;
    }

    // ── Delete Alert Time (Soft Delete) ───────────────────────────
    public async Task<bool> DeleteAsync(int id, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteAlertTime", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)userId ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var result = reader.GetInt32(reader.GetOrdinal("Result"));
            return result == 1;
        }

        return false;
    }
}
