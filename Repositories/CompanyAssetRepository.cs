using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class CompanyAssetRepository : ICompanyAssetRepository
{
    private readonly IDbConnectionFactory _factory;
    public CompanyAssetRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<CompanyAssetResponse> Data, int TotalRecords)> GetAllAsync(CompanyAssetListRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCompanyAssets", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",   req.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",     req.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",   (object?)req.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",       (object?)req.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<CompanyAssetResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<CompanyAssetResponse?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCompanyAssetById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(CreateCompanyAssetRequest req, string? documentUrl)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateCompanyAsset", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@AssetType",    req.AssetType?.Trim()    ?? "");
        cmd.Parameters.AddWithValue("@DocumentName", req.DocumentName?.Trim() ?? "");
        cmd.Parameters.AddWithValue("@CompanyName",  req.CompanyName?.Trim()  ?? "");
        cmd.Parameters.AddWithValue("@IssueDate",    string.IsNullOrEmpty(req.IssueDate)  ? (object)DBNull.Value : DateTime.Parse(req.IssueDate));
        cmd.Parameters.AddWithValue("@ExpiryDate",   string.IsNullOrEmpty(req.ExpiryDate) ? (object)DBNull.Value : DateTime.Parse(req.ExpiryDate));
        cmd.Parameters.AddWithValue("@Status",       req.Status ?? "Active");
        cmd.Parameters.AddWithValue("@DocumentUrl",  (object?)documentUrl ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Remarks",      req.Remarks?.Trim() ?? "");
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(int id, UpdateCompanyAssetRequest req, string? documentUrl)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateCompanyAsset", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",           id);
        cmd.Parameters.AddWithValue("@AssetType",    req.AssetType?.Trim()    ?? "");
        cmd.Parameters.AddWithValue("@DocumentName", req.DocumentName?.Trim() ?? "");
        cmd.Parameters.AddWithValue("@CompanyName",  req.CompanyName?.Trim()  ?? "");
        cmd.Parameters.AddWithValue("@IssueDate",    string.IsNullOrEmpty(req.IssueDate)  ? (object)DBNull.Value : DateTime.Parse(req.IssueDate));
        cmd.Parameters.AddWithValue("@ExpiryDate",   string.IsNullOrEmpty(req.ExpiryDate) ? (object)DBNull.Value : DateTime.Parse(req.ExpiryDate));
        cmd.Parameters.AddWithValue("@Status",       req.Status ?? "Active");
        cmd.Parameters.AddWithValue("@DocumentUrl",  (object?)documentUrl ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Remarks",      req.Remarks?.Trim() ?? "");
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteCompanyAsset", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM CompanyAssets WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static CompanyAssetResponse Map(SqlDataReader r) => new()
    {
        Id           = r.GetInt32(r.GetOrdinal("Id")),
        AssetCode    = r.IsDBNull(r.GetOrdinal("AssetCode"))    ? "" : r.GetString(r.GetOrdinal("AssetCode")),
        AssetType    = r.IsDBNull(r.GetOrdinal("AssetType"))    ? "" : r.GetString(r.GetOrdinal("AssetType")),
        DocumentName = r.IsDBNull(r.GetOrdinal("DocumentName")) ? "" : r.GetString(r.GetOrdinal("DocumentName")),
        CompanyName  = r.IsDBNull(r.GetOrdinal("CompanyName"))  ? "" : r.GetString(r.GetOrdinal("CompanyName")),
        IssueDate    = r.IsDBNull(r.GetOrdinal("IssueDate"))    ? null : r.GetDateTime(r.GetOrdinal("IssueDate")).ToString("yyyy-MM-dd"),
        ExpiryDate   = r.IsDBNull(r.GetOrdinal("ExpiryDate"))   ? null : r.GetDateTime(r.GetOrdinal("ExpiryDate")).ToString("yyyy-MM-dd"),
        Status       = r.IsDBNull(r.GetOrdinal("Status"))       ? "" : r.GetString(r.GetOrdinal("Status")),
        DocumentUrl  = r.IsDBNull(r.GetOrdinal("DocumentUrl"))  ? null : r.GetString(r.GetOrdinal("DocumentUrl")),
        Remarks      = r.IsDBNull(r.GetOrdinal("Remarks"))      ? "" : r.GetString(r.GetOrdinal("Remarks")),
        CreatedAt    = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt    = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
