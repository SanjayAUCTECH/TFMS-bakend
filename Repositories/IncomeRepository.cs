using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class IncomeRepository : IIncomeRepository
{
    private readonly IDbConnectionFactory _factory;
    public IncomeRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Income> Data, int TotalRecords)> GetAllAsync(IncomeListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetIncomes", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)request.DateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)request.DateTo     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Head",       (object?)request.Head       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPool",   (object?)request.FundPool   ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var list = new List<Income>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapIncome(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Income?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetIncomeById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapIncome(r) : null;
    }

    public async Task<int> CreateAsync(Income income)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateIncome", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Date",        income.Date);
        cmd.Parameters.AddWithValue("@Mode",        income.Mode);
        cmd.Parameters.AddWithValue("@Head",        income.Head);
        cmd.Parameters.AddWithValue("@FundPool",    income.FundPool);
        cmd.Parameters.AddWithValue("@Amount",      income.Amount);
        cmd.Parameters.AddWithValue("@Purpose",     income.Purpose);
        cmd.Parameters.AddWithValue("@Source",      income.Source      ?? "");
        cmd.Parameters.AddWithValue("@SourceRef",   income.SourceRef   ?? "");
        cmd.Parameters.AddWithValue("@CampId",      (object?)income.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampName",    income.CampName    ?? "");
        cmd.Parameters.AddWithValue("@PartnerId",   (object?)income.PartnerId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PartnerName", income.PartnerName ?? "");
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Income income)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateIncome", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",          income.Id);
        cmd.Parameters.AddWithValue("@Date",        income.Date);
        cmd.Parameters.AddWithValue("@Mode",        income.Mode);
        cmd.Parameters.AddWithValue("@Head",        income.Head);
        cmd.Parameters.AddWithValue("@FundPool",    income.FundPool);
        cmd.Parameters.AddWithValue("@Amount",      income.Amount);
        cmd.Parameters.AddWithValue("@Purpose",     income.Purpose);
        cmd.Parameters.AddWithValue("@Source",      income.Source      ?? "");
        cmd.Parameters.AddWithValue("@SourceRef",   income.SourceRef   ?? "");
        cmd.Parameters.AddWithValue("@CampId",      (object?)income.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampName",    income.CampName    ?? "");
        cmd.Parameters.AddWithValue("@PartnerId",   (object?)income.PartnerId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PartnerName", income.PartnerName ?? "");
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteIncome", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Incomes WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                                                AS totalEntries,
                ISNULL(SUM(Amount),0)                                                  AS totalAmount,
                ISNULL(SUM(CASE WHEN Source='Room Payment' THEN Amount ELSE 0 END),0)  AS roomRentIncome,
                ISNULL(SUM(CASE WHEN CAST(Date AS DATE) >= DATEADD(MONTH,-1,GETDATE()) THEN Amount ELSE 0 END),0) AS lastMonthAmount
            FROM Incomes", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { totalEntries=0, totalAmount=0m, roomRentIncome=0m, lastMonthAmount=0m };
        return new {
            totalEntries    = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            totalAmount     = r.IsDBNull(1) ? 0m : r.GetDecimal(1),
            roomRentIncome  = r.IsDBNull(2) ? 0m : r.GetDecimal(2),
            lastMonthAmount = r.IsDBNull(3) ? 0m : r.GetDecimal(3),
        };
    }

    private static Income MapIncome(SqlDataReader r) => new()
    {
        Id           = r.GetInt32(r.GetOrdinal("Id")),
        IncomeId     = r.GetString(r.GetOrdinal("IncomeId")),
        Date         = r.GetDateTime(r.GetOrdinal("Date")),
        Mode         = r.IsDBNull(r.GetOrdinal("Mode"))         ? "" : r.GetString(r.GetOrdinal("Mode")),
        Head         = r.IsDBNull(r.GetOrdinal("Head"))         ? "" : r.GetString(r.GetOrdinal("Head")),
        FundPool     = r.IsDBNull(r.GetOrdinal("FundPool"))     ? "" : r.GetString(r.GetOrdinal("FundPool")),
        FundPoolName = r.IsDBNull(r.GetOrdinal("FundPoolName")) ? "" : r.GetString(r.GetOrdinal("FundPoolName")),
        Amount       = r.GetDecimal(r.GetOrdinal("Amount")),
        Purpose      = r.IsDBNull(r.GetOrdinal("Purpose"))      ? "" : r.GetString(r.GetOrdinal("Purpose")),
        Source       = r.IsDBNull(r.GetOrdinal("Source"))       ? "" : r.GetString(r.GetOrdinal("Source")),
        SourceRef    = r.IsDBNull(r.GetOrdinal("SourceRef"))    ? "" : r.GetString(r.GetOrdinal("SourceRef")),
        CampId       = r.IsDBNull(r.GetOrdinal("CampId"))       ? (int?)null : r.GetInt32(r.GetOrdinal("CampId")),
        CampName     = r.IsDBNull(r.GetOrdinal("CampName"))     ? "" : r.GetString(r.GetOrdinal("CampName")),
        PartnerId    = r.IsDBNull(r.GetOrdinal("PartnerId"))    ? (int?)null : r.GetInt32(r.GetOrdinal("PartnerId")),
        PartnerName  = r.IsDBNull(r.GetOrdinal("PartnerName"))  ? "" : r.GetString(r.GetOrdinal("PartnerName")),
        ContractId   = r.IsDBNull(r.GetOrdinal("ContractId"))   ? "" : r.GetString(r.GetOrdinal("ContractId")),
        ContractCode = r.IsDBNull(r.GetOrdinal("ContractCode")) ? "" : r.GetString(r.GetOrdinal("ContractCode")),
        CreatedAt    = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt    = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
