using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class SalonExpenseReportRepository : ISalonExpenseReportRepository
{
    private readonly IDbConnectionFactory _factory;
    public SalonExpenseReportRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── Report rows ────────────────────────────────────────────────────────────
    public async Task<(IEnumerable<SalonExpenseReportRow> Data, int Total)> GetReportAsync(
        SalonExpenseReportRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonExpenseReport", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@DateFrom",   string.IsNullOrEmpty(request.DateFrom)
                                                       ? DBNull.Value
                                                       : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",     string.IsNullOrEmpty(request.DateTo)
                                                       ? DBNull.Value
                                                       : (object)DateTime.Parse(request.DateTo));
        cmd.Parameters.AddWithValue("@Head",       (object?)request.Head ?? DBNull.Value);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list = new List<SalonExpenseReportRow>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new SalonExpenseReportRow
            {
                Id            = reader.GetInt32(reader.GetOrdinal("Id")),
                Date          = reader.GetDateTime(reader.GetOrdinal("Date")),
                RecipientName = reader.IsDBNull(reader.GetOrdinal("RecipientName")) ? null : reader["RecipientName"].ToString(),
                Head          = reader.IsDBNull(reader.GetOrdinal("Head"))          ? null : reader["Head"].ToString(),
                Amount        = reader.IsDBNull(reader.GetOrdinal("Amount"))        ? 0    : reader.GetDecimal(reader.GetOrdinal("Amount")),
                Description   = reader.IsDBNull(reader.GetOrdinal("Description"))   ? null : reader["Description"].ToString(),
                FundType      = reader.IsDBNull(reader.GetOrdinal("FundType"))      ? null : reader["FundType"].ToString(),
                SalonId       = reader.IsDBNull(reader.GetOrdinal("SalonId"))       ? null : reader.GetInt32(reader.GetOrdinal("SalonId")),
                SalonName     = reader.IsDBNull(reader.GetOrdinal("SalonName"))     ? null : reader["SalonName"].ToString(),
                Status        = reader.IsDBNull(reader.GetOrdinal("Status"))        ? null : reader["Status"].ToString(),
                CreatedAt     = reader.IsDBNull(reader.GetOrdinal("CreatedAt"))     ? DateTime.MinValue : reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            });
        }

        await reader.CloseAsync();
        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        return (list, total);
    }

    // ── Cards ──────────────────────────────────────────────────────────────────
    public async Task<SalonExpenseReportCards> GetCardsAsync(
        string? dateFrom, string? dateTo, string? head)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonExpenseReportCards", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@DateFrom", string.IsNullOrEmpty(dateFrom)
                                                     ? DBNull.Value
                                                     : (object)DateTime.Parse(dateFrom));
        cmd.Parameters.AddWithValue("@DateTo",   string.IsNullOrEmpty(dateTo)
                                                     ? DBNull.Value
                                                     : (object)DateTime.Parse(dateTo));
        cmd.Parameters.AddWithValue("@Head",     (object?)head ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new SalonExpenseReportCards
            {
                TotalStaffFund   = reader.IsDBNull(reader.GetOrdinal("TotalStaffFund"))   ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalStaffFund")),
                TotalCompanyFund = reader.IsDBNull(reader.GetOrdinal("TotalCompanyFund")) ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalCompanyFund")),
                GrandTotal       = reader.IsDBNull(reader.GetOrdinal("GrandTotal"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("GrandTotal")),
                TotalEntries     = reader.IsDBNull(reader.GetOrdinal("TotalEntries"))     ? 0 : reader.GetInt32(reader.GetOrdinal("TotalEntries")),
            };
        }

        return new SalonExpenseReportCards();
    }
}
