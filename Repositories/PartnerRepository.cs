using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class PartnerRepository : IPartnerRepository
{
    private readonly IDbConnectionFactory _factory;
    public PartnerRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Partner> Data, int TotalRecords)> GetAllAsync(PartnerListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPartners", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",     (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",         (object?)request.SortBy    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",         (object?)request.Status    ?? DBNull.Value);

        var total   = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var list = new List<Partner>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(MapPartner(reader));

        await reader.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Partner?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPartnerById", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync()) return MapPartner(reader);
        return null;
    }

    public async Task<int> CreateAsync(Partner p)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreatePartner", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@Name",    p.Name);
        cmd.Parameters.AddWithValue("@Contact", p.Contact);
        cmd.Parameters.AddWithValue("@Mobile",  p.Mobile);
        cmd.Parameters.AddWithValue("@Email",   p.Email);
        cmd.Parameters.AddWithValue("@Status",  p.Status);

        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Partner p)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdatePartner", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@Id",      p.Id);
        cmd.Parameters.AddWithValue("@Name",    p.Name);
        cmd.Parameters.AddWithValue("@Contact", p.Contact);
        cmd.Parameters.AddWithValue("@Mobile",  p.Mobile);
        cmd.Parameters.AddWithValue("@Email",   p.Email);
        cmd.Parameters.AddWithValue("@Status",  p.Status);

        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeletePartner", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                            AS total,
                SUM(CASE WHEN Status='Active'   THEN 1 ELSE 0 END) AS active,
                SUM(CASE WHEN Status='Inactive' THEN 1 ELSE 0 END) AS inactive,
                (SELECT COUNT(DISTINCT PartnerId) FROM CampPartners) AS assigned
            FROM Partners", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { total=0, active=0, inactive=0, assigned=0 };
        return new {
            total    = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            active   = r.IsDBNull(1) ? 0 : r.GetInt32(1),
            inactive = r.IsDBNull(2) ? 0 : r.GetInt32(2),
            assigned = r.IsDBNull(3) ? 0 : r.GetInt32(3),
        };
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Partners WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        var count = (int)(await cmd.ExecuteScalarAsync())!;
        return count > 0;
    }

    private static Partner MapPartner(SqlDataReader r) => new()
    {
        Id        = r.GetInt32(r.GetOrdinal("Id")),
        Code      = r.GetString(r.GetOrdinal("Code")),
        Name      = r.GetString(r.GetOrdinal("Name")),
        Contact   = r.IsDBNull(r.GetOrdinal("Contact")) ? "" : r.GetString(r.GetOrdinal("Contact")),
        Mobile    = r.IsDBNull(r.GetOrdinal("Mobile"))  ? "" : r.GetString(r.GetOrdinal("Mobile")),
        Email     = r.IsDBNull(r.GetOrdinal("Email"))   ? "" : r.GetString(r.GetOrdinal("Email")),
        Status    = r.GetString(r.GetOrdinal("Status")),
        CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
