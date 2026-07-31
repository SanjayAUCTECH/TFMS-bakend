using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class CompanyRepository : ICompanyRepository
{
    private readonly IDbConnectionFactory _factory;

    public CompanyRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<int> CreateAsync(CreateCompanyRequest request, string? addedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = @"INSERT INTO Companies (CompanyName, Status, AddedBy, CreatedAt, UpdatedAt)
                    VALUES (@CompanyName, @Status, @AddedBy, GETUTCDATE(), GETUTCDATE());
                    SELECT SCOPE_IDENTITY();";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@CompanyName", request.CompanyName);
        cmd.Parameters.AddWithValue("@Status", request.Status);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)addedBy ?? DBNull.Value);

        var result = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<(IEnumerable<CompanyResponse> Companies, int TotalRecords)> GetAllAsync(
        int pageNumber, int pageSize, string? search, string? status)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Build inline SQL — works even if SP not yet deployed
        var countSql = @"SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0
            AND (@Search IS NULL OR CompanyName LIKE '%' + @Search + '%')
            AND (@Status IS NULL OR Status = @Status)";

        var dataSql = @"SELECT Id, CompanyName, Status, AddedBy, UpdatedBy, DeletedBy, IsDeleted, CreatedAt, UpdatedAt
            FROM Companies WHERE IsDeleted = 0
            AND (@Search IS NULL OR CompanyName LIKE '%' + @Search + '%')
            AND (@Status IS NULL OR Status = @Status)
            ORDER BY CreatedAt DESC
            OFFSET (@Offset) ROWS FETCH NEXT @PageSize ROWS ONLY";

        // Get total count
        await using var countCmd = new SqlCommand(countSql, conn);
        countCmd.Parameters.AddWithValue("@Search", (object?)search ?? DBNull.Value);
        countCmd.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);
        var totalRecords = (int)(await countCmd.ExecuteScalarAsync())!;

        // Get page data
        await using var dataCmd = new SqlCommand(dataSql, conn);
        dataCmd.Parameters.AddWithValue("@Search", (object?)search ?? DBNull.Value);
        dataCmd.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);
        dataCmd.Parameters.AddWithValue("@Offset", (pageNumber - 1) * pageSize);
        dataCmd.Parameters.AddWithValue("@PageSize", pageSize);

        var list = new List<CompanyResponse>();
        await using var reader = await dataCmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            list.Add(new CompanyResponse
            {
                Id          = reader.GetInt32(reader.GetOrdinal("Id")),
                CompanyName = reader.GetString(reader.GetOrdinal("CompanyName")),
                Status      = reader.GetString(reader.GetOrdinal("Status")),
                AddedBy     = reader.IsDBNull(reader.GetOrdinal("AddedBy")) ? null : reader.GetString(reader.GetOrdinal("AddedBy")),
                UpdatedBy   = reader.IsDBNull(reader.GetOrdinal("UpdatedBy")) ? null : reader.GetString(reader.GetOrdinal("UpdatedBy")),
                DeletedBy   = reader.IsDBNull(reader.GetOrdinal("DeletedBy")) ? null : reader.GetString(reader.GetOrdinal("DeletedBy")),
                IsDeleted   = reader.GetBoolean(reader.GetOrdinal("IsDeleted")),
                CreatedAt   = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt   = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
            });
        }

        return (list, totalRecords);
    }

    public async Task<CompanyResponse?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = @"SELECT Id, CompanyName, Status, AddedBy, UpdatedBy, DeletedBy, IsDeleted, CreatedAt, UpdatedAt
                    FROM Companies WHERE Id = @Id AND IsDeleted = 0";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        return new CompanyResponse
        {
            Id          = reader.GetInt32(reader.GetOrdinal("Id")),
            CompanyName = reader.GetString(reader.GetOrdinal("CompanyName")),
            Status      = reader.GetString(reader.GetOrdinal("Status")),
            AddedBy     = reader.IsDBNull(reader.GetOrdinal("AddedBy")) ? null : reader.GetString(reader.GetOrdinal("AddedBy")),
            UpdatedBy   = reader.IsDBNull(reader.GetOrdinal("UpdatedBy")) ? null : reader.GetString(reader.GetOrdinal("UpdatedBy")),
            DeletedBy   = reader.IsDBNull(reader.GetOrdinal("DeletedBy")) ? null : reader.GetString(reader.GetOrdinal("DeletedBy")),
            IsDeleted   = reader.GetBoolean(reader.GetOrdinal("IsDeleted")),
            CreatedAt   = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            UpdatedAt   = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
        };
    }

    public async Task UpdateAsync(int id, UpdateCompanyRequest request, string? updatedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = @"UPDATE Companies SET
                        CompanyName = ISNULL(@CompanyName, CompanyName),
                        Status      = ISNULL(@Status, Status),
                        UpdatedBy   = @UpdatedBy,
                        UpdatedAt   = GETUTCDATE()
                    WHERE Id = @Id AND IsDeleted = 0";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@CompanyName", (object?)request.CompanyName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status", (object?)request.Status ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)updatedBy ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteAsync(int id, string? deletedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = @"UPDATE Companies SET IsDeleted = 1, DeletedBy = @DeletedBy, UpdatedAt = GETUTCDATE()
                    WHERE Id = @Id AND IsDeleted = 0";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }
}
