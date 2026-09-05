using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class CompanyExpensePostingRepository : ICompanyExpensePostingRepository
{
    private readonly IDbConnectionFactory _factory;

    public CompanyExpensePostingRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── GET ALL ────────────────────────────────────────────────────────────────
    public async Task<(IEnumerable<CompanyExpensePosting> Data, int Total)> GetAllAsync(
        CompanyExpensePostingListRequest request)
    {
        int pageNumber = request.ResolvedPageNumber;
        int pageSize   = request.ResolvedPageSize;

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetCompanyExpensePosting", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@PageNumber",  pageNumber);
        cmd.Parameters.AddWithValue("@PageSize",    pageSize);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SalonId",     (object?)request.SalonId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Type",        (object?)request.Type       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",    string.IsNullOrEmpty(request.DateFrom)
                                                        ? DBNull.Value
                                                        : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",      string.IsNullOrEmpty(request.DateTo)
                                                        ? DBNull.Value
                                                        : (object)DateTime.Parse(request.DateTo));
        cmd.Parameters.AddWithValue("@Status",      (object?)request.Status ?? DBNull.Value);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list = new List<CompanyExpensePosting>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(MapRow(reader));

        await reader.CloseAsync();
        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;

        return (list, total);
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<CompanyExpensePosting?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetCompanyExpensePostingById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync()) return MapRow(reader);
        return null;
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<int> CreateAsync(CompanyExpensePosting model)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_CreateCompanyExpensePosting", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Date",          model.Date);
        cmd.Parameters.AddWithValue("@Type",          model.Type);
        cmd.Parameters.AddWithValue("@RecipientName", (object?)model.RecipientName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Head",          (object?)model.Head          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Amount",        model.Amount);
        cmd.Parameters.AddWithValue("@Mode",          model.Mode);
        cmd.Parameters.AddWithValue("@SalonId",       (object?)model.SalonId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description",   (object?)model.Description   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",        model.Status);
        cmd.Parameters.AddWithValue("@AddedBy",       (object?)model.AddedBy       ?? DBNull.Value);

        var newIdParam = new SqlParameter("@NewId", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newIdParam);

        await cmd.ExecuteNonQueryAsync();
        return newIdParam.Value == DBNull.Value ? 0 : (int)newIdParam.Value;
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<bool> UpdateAsync(CompanyExpensePosting model)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateCompanyExpensePosting", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id",            model.Id);
        cmd.Parameters.AddWithValue("@Date",          model.Date);
        cmd.Parameters.AddWithValue("@Type",          model.Type);
        cmd.Parameters.AddWithValue("@RecipientName", (object?)model.RecipientName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Head",          (object?)model.Head          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Amount",        model.Amount);
        cmd.Parameters.AddWithValue("@Mode",          model.Mode);
        cmd.Parameters.AddWithValue("@SalonId",       (object?)model.SalonId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description",   (object?)model.Description   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",        model.Status);
        cmd.Parameters.AddWithValue("@UpdatedBy",     (object?)model.UpdatedBy?.ToString() ?? DBNull.Value);

        int rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    // ── SOFT DELETE ────────────────────────────────────────────────────────────
    public async Task<bool> DeleteAsync(int id, string? deletedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteCompanyExpensePosting", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);

        int rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    // ── SUMMARY ────────────────────────────────────────────────────────────────
    public async Task<IEnumerable<CompanyExpenseSummaryResponse>> GetSummaryAsync(
        int? salonId, string? dateFrom, string? dateTo)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetCompanyExpenseSummary", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@SalonId",  (object?)salonId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom", string.IsNullOrEmpty(dateFrom)
                                                     ? DBNull.Value
                                                     : (object)DateTime.Parse(dateFrom));
        cmd.Parameters.AddWithValue("@DateTo",   string.IsNullOrEmpty(dateTo)
                                                     ? DBNull.Value
                                                     : (object)DateTime.Parse(dateTo));

        var list = new List<CompanyExpenseSummaryResponse>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new CompanyExpenseSummaryResponse
            {
                Type         = reader["Type"]?.ToString(),
                TotalEntries = reader.IsDBNull(reader.GetOrdinal("TotalEntries")) ? 0 : reader.GetInt32(reader.GetOrdinal("TotalEntries")),
                TotalAmount  = reader.IsDBNull(reader.GetOrdinal("TotalAmount"))  ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
            });
        }
        return list;
    }

    // ── Row Mapper ─────────────────────────────────────────────────────────────
    private static CompanyExpensePosting MapRow(SqlDataReader r) => new()
    {
        Id            = r.GetInt32(r.GetOrdinal("Id")),
        Date          = r.GetDateTime(r.GetOrdinal("Date")),
        Type          = r["Type"]?.ToString() ?? string.Empty,
        RecipientName = r.IsDBNull(r.GetOrdinal("RecipientName")) ? null : r["RecipientName"].ToString(),
        Head          = r.IsDBNull(r.GetOrdinal("Head"))          ? null : r["Head"].ToString(),
        Amount        = r.IsDBNull(r.GetOrdinal("Amount"))        ? 0    : r.GetDecimal(r.GetOrdinal("Amount")),
        Mode          = r["Mode"]?.ToString() ?? "Cash",
        SalonId       = r.IsDBNull(r.GetOrdinal("SalonId"))       ? null : r.GetInt32(r.GetOrdinal("SalonId")),
        SalonName     = r.IsDBNull(r.GetOrdinal("SalonName"))     ? null : r["SalonName"].ToString(),
        Description   = r.IsDBNull(r.GetOrdinal("Description"))   ? null : r["Description"].ToString(),
        Status        = r["Status"]?.ToString() ?? "Active",
        CreatedAt     = r.IsDBNull(r.GetOrdinal("CreatedAt"))     ? DateTime.MinValue : r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt     = r.IsDBNull(r.GetOrdinal("UpdatedAt"))     ? null : r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
