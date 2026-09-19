using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class OutsourceMoneyRepository : IOutsourceMoneyRepository
{
    private readonly IDbConnectionFactory _factory;
    public OutsourceMoneyRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<OutsourceMoney> data, int total)> GetAllAsync(OutsourceMoneyListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetAllOutsourceMoney", conn) { CommandType = CommandType.StoredProcedure };
        
        cmd.Parameters.AddWithValue("@Search", (object?)request.Search ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId", (object?)request.CampId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolId", (object?)request.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode", (object?)request.Mode ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month", (object?)request.Month ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FromDate", (object?)request.FromDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate", (object?)request.ToDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);

        var list = new List<OutsourceMoney>();
        await using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            list.Add(new OutsourceMoney
            {
                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                Date = reader.GetDateTime(reader.GetOrdinal("Date")),
                Month = reader.IsDBNull(reader.GetOrdinal("Month")) ? "" : reader.GetString(reader.GetOrdinal("Month")),
                CampId = reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName = reader.IsDBNull(reader.GetOrdinal("CampName")) ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                FundPoolId = reader.GetInt32(reader.GetOrdinal("FundPoolId")),
                FundPoolName = reader.IsDBNull(reader.GetOrdinal("FundPoolName")) ? "" : reader.GetString(reader.GetOrdinal("FundPoolName")),
                Amount = reader.GetDecimal(reader.GetOrdinal("Amount")),
                Mode = reader.IsDBNull(reader.GetOrdinal("Mode")) ? "" : reader.GetString(reader.GetOrdinal("Mode")),
                Purpose = reader.IsDBNull(reader.GetOrdinal("Purpose")) ? "" : reader.GetString(reader.GetOrdinal("Purpose")),
                Remarks = reader.IsDBNull(reader.GetOrdinal("Remarks")) ? "" : reader.GetString(reader.GetOrdinal("Remarks")),
                ReferenceNo = reader.IsDBNull(reader.GetOrdinal("ReferenceNo")) ? "" : reader.GetString(reader.GetOrdinal("ReferenceNo")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
            });
        }

        await reader.NextResultAsync();
        var total = 0;
        if (await reader.ReadAsync())
            total = reader.GetInt32(0);

        return (list, total);
    }

    public async Task<OutsourceMoney?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOutsourceMoneyById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new OutsourceMoney
            {
                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                Date = reader.GetDateTime(reader.GetOrdinal("Date")),
                Month = reader.IsDBNull(reader.GetOrdinal("Month")) ? "" : reader.GetString(reader.GetOrdinal("Month")),
                CampId = reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName = reader.IsDBNull(reader.GetOrdinal("CampName")) ? "" : reader.GetString(reader.GetOrdinal("CampName")),
                FundPoolId = reader.GetInt32(reader.GetOrdinal("FundPoolId")),
                FundPoolName = reader.IsDBNull(reader.GetOrdinal("FundPoolName")) ? "" : reader.GetString(reader.GetOrdinal("FundPoolName")),
                Amount = reader.GetDecimal(reader.GetOrdinal("Amount")),
                Mode = reader.IsDBNull(reader.GetOrdinal("Mode")) ? "" : reader.GetString(reader.GetOrdinal("Mode")),
                Purpose = reader.IsDBNull(reader.GetOrdinal("Purpose")) ? "" : reader.GetString(reader.GetOrdinal("Purpose")),
                Remarks = reader.IsDBNull(reader.GetOrdinal("Remarks")) ? "" : reader.GetString(reader.GetOrdinal("Remarks")),
                ReferenceNo = reader.IsDBNull(reader.GetOrdinal("ReferenceNo")) ? "" : reader.GetString(reader.GetOrdinal("ReferenceNo")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt = reader.GetDateTime(reader.GetOrdinal("UpdatedAt"))
            };
        }
        return null;
    }

    public async Task<int> CreateAsync(OutsourceMoney entity)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateOutsourceMoney", conn) { CommandType = CommandType.StoredProcedure };
        
        cmd.Parameters.AddWithValue("@Date", entity.Date);
        cmd.Parameters.AddWithValue("@Month", entity.Month);
        cmd.Parameters.AddWithValue("@CampId", entity.CampId);
        cmd.Parameters.AddWithValue("@FundPoolId", entity.FundPoolId);
        cmd.Parameters.AddWithValue("@Amount", entity.Amount);
        cmd.Parameters.AddWithValue("@Mode", entity.Mode);
        cmd.Parameters.AddWithValue("@Purpose", entity.Purpose);
        cmd.Parameters.AddWithValue("@Remarks", (object?)entity.Remarks ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ReferenceNo", (object?)entity.ReferenceNo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)entity.AddedBy ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return reader.GetInt32(0);
        
        return 0;
    }

    public async Task UpdateAsync(OutsourceMoney entity)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateOutsourceMoney", conn) { CommandType = CommandType.StoredProcedure };
        
        cmd.Parameters.AddWithValue("@Id", entity.Id);
        cmd.Parameters.AddWithValue("@Date", entity.Date);
        cmd.Parameters.AddWithValue("@Month", entity.Month);
        cmd.Parameters.AddWithValue("@CampId", entity.CampId);
        cmd.Parameters.AddWithValue("@FundPoolId", entity.FundPoolId);
        cmd.Parameters.AddWithValue("@Amount", entity.Amount);
        cmd.Parameters.AddWithValue("@Mode", entity.Mode);
        cmd.Parameters.AddWithValue("@Purpose", entity.Purpose);
        cmd.Parameters.AddWithValue("@Remarks", (object?)entity.Remarks ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ReferenceNo", (object?)entity.ReferenceNo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<bool> DeleteAsync(int id, int? userId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOutsourceMoney", conn) { CommandType = CommandType.StoredProcedure };
        
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@UpdatedBy", (object?)userId ?? DBNull.Value);

        // Stored procedure returns RowsAffected as result set
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var rowsAffected = reader.GetInt32(0);
            return rowsAffected > 0;
        }
        return false;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOutsourceMoneyStats", conn) { CommandType = CommandType.StoredProcedure };

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new
            {
                totalRecords = reader.GetInt32(reader.GetOrdinal("TotalRecords")),
                totalAmount = reader.GetDecimal(reader.GetOrdinal("TotalAmount")),
                thisMonthAmount = reader.GetDecimal(reader.GetOrdinal("ThisMonthAmount")),
                thisYearAmount = reader.GetDecimal(reader.GetOrdinal("ThisYearAmount"))
            };
        }

        return new
        {
            totalRecords = 0,
            totalAmount = 0m,
            thisMonthAmount = 0m,
            thisYearAmount = 0m
        };
    }
}
