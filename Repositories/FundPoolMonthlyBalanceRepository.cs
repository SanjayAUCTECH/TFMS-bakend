using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class FundPoolMonthlyBalanceRepository : IFundPoolMonthlyBalanceRepository
{
    private readonly IDbConnectionFactory _factory;
    public FundPoolMonthlyBalanceRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<FundPoolMonthlyBalance>> SaveMonthlyBalanceAsync(
        int reportMonth, int reportYear, DateTime? reportDate, int? userId, 
        List<FundPoolMonthlyBalanceItem> fundPools)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Create DataTable for the table-valued parameter
        var table = new DataTable();
        table.Columns.Add("FundPoolId", typeof(int));
        table.Columns.Add("FundPoolName", typeof(string));
        table.Columns.Add("CurrentFundPool", typeof(decimal));
        table.Columns.Add("BufferFundPool", typeof(decimal));
        table.Columns.Add("TotalFundPool", typeof(decimal));

        foreach (var fp in fundPools)
        {
            table.Rows.Add(
                fp.FundPoolId,
                fp.FundPoolName,
                fp.CurrentFundPool,
                fp.BufferFundPool,
                fp.TotalFundPool
            );
        }

        await using var cmd = new SqlCommand("sp_SaveFundPoolMonthlyBalance", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@ReportMonth", reportMonth);
        cmd.Parameters.AddWithValue("@ReportYear", reportYear);
        cmd.Parameters.AddWithValue("@ReportDate", (object?)reportDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UserId", (object?)userId ?? DBNull.Value);
        
        var tvpParam = cmd.Parameters.AddWithValue("@FundPoolData", table);
        tvpParam.SqlDbType = SqlDbType.Structured;
        tvpParam.TypeName = "dbo.FundPoolMonthlyBalanceTableType";

        var list = new List<FundPoolMonthlyBalance>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(MapBalance(reader));

        return list;
    }

    public async Task<(IEnumerable<FundPoolMonthlyBalance> Data, FundPoolMonthlyBalanceTotals Totals)> GetMonthlyBalanceAsync(
        int reportMonth, int reportYear)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetFundPoolMonthlyBalance", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@ReportMonth", reportMonth);
        cmd.Parameters.AddWithValue("@ReportYear", reportYear);

        var list = new List<FundPoolMonthlyBalance>();
        await using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
            list.Add(MapBalance(reader));

        var totals = new FundPoolMonthlyBalanceTotals();
        if (await reader.NextResultAsync() && await reader.ReadAsync())
        {
            totals.TotalCurrentFundPool = reader.IsDBNull(0) ? 0 : reader.GetDecimal(0);
            totals.TotalBufferFundPool = reader.IsDBNull(1) ? 0 : reader.GetDecimal(1);
            totals.NetTotal = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2);
        }

        return (list, totals);
    }

    public async Task<(IEnumerable<FundPoolMonthlyBalanceSummaryResponse> Data, int TotalRecords)> GetAllMonthlyBalancesAsync(
        FundPoolMonthlyBalanceListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetAllFundPoolMonthlyBalances", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ReportYear", (object?)request.ReportYear ?? DBNull.Value);

        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var list = new List<FundPoolMonthlyBalanceSummaryResponse>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            list.Add(MapSummary(reader));

        await reader.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<int> DeleteMonthlyBalanceAsync(int reportMonth, int reportYear, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteFundPoolMonthlyBalance", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@ReportMonth", reportMonth);
        cmd.Parameters.AddWithValue("@ReportYear", reportYear);
        cmd.Parameters.AddWithValue("@UserId", (object?)userId ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return reader.GetInt32(0);

        return 0;
    }

    private static FundPoolMonthlyBalance MapBalance(SqlDataReader r) => new()
    {
        Id = r.GetInt32(r.GetOrdinal("Id")),
        FundPoolId = r.GetInt32(r.GetOrdinal("FundPoolId")),
        FundPoolName = r.GetString(r.GetOrdinal("FundPoolName")),
        ReportMonth = r.GetInt32(r.GetOrdinal("ReportMonth")),
        ReportYear = r.GetInt32(r.GetOrdinal("ReportYear")),
        ReportDate = r.GetDateTime(r.GetOrdinal("ReportDate")),
        CurrentFundPool = r.GetDecimal(r.GetOrdinal("CurrentFundPool")),
        BufferFundPool = r.GetDecimal(r.GetOrdinal("BufferFundPool")),
        TotalFundPool = r.GetDecimal(r.GetOrdinal("TotalFundPool")),
        Status = r.GetString(r.GetOrdinal("Status")),
        CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static FundPoolMonthlyBalanceSummaryResponse MapSummary(SqlDataReader r) => new()
    {
        ReportMonth = r.GetInt32(r.GetOrdinal("ReportMonth")),
        ReportYear = r.GetInt32(r.GetOrdinal("ReportYear")),
        ReportDate = r.GetDateTime(r.GetOrdinal("ReportDate")),
        TotalFundPools = r.GetInt32(r.GetOrdinal("TotalFundPools")),
        TotalCurrentFundPool = r.GetDecimal(r.GetOrdinal("TotalCurrentFundPool")),
        TotalBufferFundPool = r.GetDecimal(r.GetOrdinal("TotalBufferFundPool")),
        NetTotal = r.GetDecimal(r.GetOrdinal("NetTotal")),
        CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt")),
    };
}
