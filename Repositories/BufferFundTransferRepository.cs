using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class BufferFundTransferRepository : IBufferFundTransferRepository
{
    private readonly IDbConnectionFactory _factory;
    public BufferFundTransferRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<BufferFundTransferResponse> Data, int Total)> GetAllAsync(
        BufferFundTransferListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetBufferFundTransfer", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@PageNumber",           request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",             request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",           (object?)request.SearchText           ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolId",           (object?)request.FundPoolId            ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CurrentFundTransferId",(object?)request.CurrentFundTransferId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@BufferMonth",          (object?)request.Month                 ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",               (object?)request.Status                ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",             string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",               string.IsNullOrEmpty(request.DateTo)   ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list = new List<BufferFundTransferResponse>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync()) list.Add(Map(reader));
        await reader.CloseAsync();
        return (list, totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value);
    }

    public async Task<BufferFundTransferResponse?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetBufferFundTransferById", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync()) return Map(reader);
        return null;
    }

    public async Task<int> CreateAsync(CreateBufferFundTransferRequest request, string? addedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateBufferFundTransfer", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@BufferTransferDate",   request.Date.Date);
        cmd.Parameters.AddWithValue("@FromBufferFundPoolId", request.FromFundPoolId);
        cmd.Parameters.AddWithValue("@ToBufferFundPoolId",   (object?)request.ToFundPoolId          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CurrentFundTransferId",(object?)request.CurrentFundTransferId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@BufferAmount",         request.Amount);
        cmd.Parameters.AddWithValue("@BufferMonth",          request.Month);
        cmd.Parameters.AddWithValue("@Description",          (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",               request.Status);
        cmd.Parameters.AddWithValue("@AddedBy",              (object?)addedBy ?? DBNull.Value);

        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return newId.Value == DBNull.Value ? 0 : (int)newId.Value;
    }

    public async Task UpdateAsync(int id, UpdateBufferFundTransferRequest request, string? updatedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateBufferFundTransfer", conn)
            { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@Id",                   id);
        cmd.Parameters.AddWithValue("@BufferTransferDate",   request.Date.Date);
        cmd.Parameters.AddWithValue("@FromBufferFundPoolId", request.FromFundPoolId);
        cmd.Parameters.AddWithValue("@ToBufferFundPoolId",   (object?)request.ToFundPoolId          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CurrentFundTransferId",(object?)request.CurrentFundTransferId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@BufferAmount",         request.Amount);
        cmd.Parameters.AddWithValue("@BufferMonth",          request.Month);
        cmd.Parameters.AddWithValue("@Description",          (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",               request.Status);
        cmd.Parameters.AddWithValue("@UpdatedBy",            (object?)updatedBy ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteAsync(int id, string? deletedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteBufferFundTransfer", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
    }

    // Helper: returns column ordinal if it exists, otherwise -1
    private static int SafeOrdinal(SqlDataReader r, string columnName)
    {
        try { return r.GetOrdinal(columnName); }
        catch (IndexOutOfRangeException) { return -1; }
    }

    private static BufferFundTransferResponse Map(SqlDataReader r)
    {
        var transactionTypeOrdinal = SafeOrdinal(r, "TransactionType");
        var signedAmountOrdinal    = SafeOrdinal(r, "SignedAmount");

        return new()
        {
            BufferFundTransferId  = r.GetInt32(r.GetOrdinal("BufferFundTransferId")),
            BufferTransferDate    = r.GetDateTime(r.GetOrdinal("BufferTransferDate")),
            FromBufferFundPoolId  = r.GetInt32(r.GetOrdinal("FromBufferFundPoolId")),
            FromFundPoolName      = r["FromFundPoolName"]?.ToString(),
            ToBufferFundPoolId    = r.IsDBNull(r.GetOrdinal("ToBufferFundPoolId"))    ? null : r.GetInt32(r.GetOrdinal("ToBufferFundPoolId")),
            ToFundPoolName        = r.IsDBNull(r.GetOrdinal("ToFundPoolName"))        ? null : r["ToFundPoolName"].ToString(),
            CurrentFundTransferId = r.IsDBNull(r.GetOrdinal("CurrentFundTransferId")) ? null : r.GetInt32(r.GetOrdinal("CurrentFundTransferId")),
            BufferAmount          = r.IsDBNull(r.GetOrdinal("BufferAmount"))          ? 0    : r.GetDecimal(r.GetOrdinal("BufferAmount")),
            BufferMonth           = r["BufferMonth"]?.ToString(),
            Description           = r.IsDBNull(r.GetOrdinal("Description"))           ? null : r["Description"].ToString(),
            Status                = r["Status"]?.ToString(),
            AddedBy               = r.IsDBNull(r.GetOrdinal("AddedBy"))               ? null : r["AddedBy"].ToString(),
            CreatedAt             = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt             = r.IsDBNull(r.GetOrdinal("UpdatedAt"))             ? null : r.GetDateTime(r.GetOrdinal("UpdatedAt")),
            TransactionType       = transactionTypeOrdinal < 0 || r.IsDBNull(transactionTypeOrdinal) ? null : r.GetString(transactionTypeOrdinal),
            SignedAmount          = signedAmountOrdinal    < 0 || r.IsDBNull(signedAmountOrdinal)    ? 0    : r.GetDecimal(signedAmountOrdinal),
        };
    }
}
