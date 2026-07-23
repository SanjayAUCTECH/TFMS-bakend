using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class WaiverRepository : IWaiverRepository
{
    private readonly IDbConnectionFactory _factory;
    public WaiverRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Waiver> Data, int TotalRecords)> GetAllAsync(WaiverListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetWaivers", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@TenantId",      (object?)request.TenantId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractId",    (object?)request.ContractId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",      (object?)request.DateFrom    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",        (object?)request.DateTo      ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Waiver>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Waiver?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetWaiverById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(Waiver w)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateWaiver", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TenantId",      w.TenantId);
        cmd.Parameters.AddWithValue("@ContractId",    w.ContractId);
        cmd.Parameters.AddWithValue("@InstallmentNo", w.InstallmentNo);
        cmd.Parameters.AddWithValue("@WaiverAmount",  w.WaiverAmount);
        cmd.Parameters.AddWithValue("@Remark",        w.Remark);
        cmd.Parameters.AddWithValue("@WaiverDate",    w.WaiverDate);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<int> CreateWithRoomsAsync(Waiver w, string roomWaiversJson)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateRoomWaiver", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TenantId",        w.TenantId);
        cmd.Parameters.AddWithValue("@ContractId",      w.ContractId);
        cmd.Parameters.AddWithValue("@InstallmentNo",   w.InstallmentNo);
        cmd.Parameters.AddWithValue("@WaiverAmount",    w.WaiverAmount);
        cmd.Parameters.AddWithValue("@Remark",          w.Remark);
        cmd.Parameters.AddWithValue("@WaiverDate",      w.WaiverDate);
        cmd.Parameters.AddWithValue("@CreatedBy",       w.CreatedBy);
        cmd.Parameters.AddWithValue("@RoomWaiversJson", roomWaiversJson);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteWaiver", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    private static Waiver Map(SqlDataReader r) => new()
    {
        Id             = r.GetInt32(r.GetOrdinal("Id")),
        TenantId       = r.GetInt32(r.GetOrdinal("TenantId")),
        TenantName     = r.IsDBNull(r.GetOrdinal("TenantName")) ? "" : r.GetString(r.GetOrdinal("TenantName")),
        ContractId     = r.GetString(r.GetOrdinal("ContractId")),
        InstallmentNo  = r.GetInt32(r.GetOrdinal("InstallmentNo")),
        OriginalAmount = r.GetDecimal(r.GetOrdinal("OriginalAmount")),
        WaiverAmount   = r.GetDecimal(r.GetOrdinal("WaiverAmount")),
        BalanceAmount  = r.GetDecimal(r.GetOrdinal("BalanceAmount")),
        Remark         = r.IsDBNull(r.GetOrdinal("Remark")) ? "" : r.GetString(r.GetOrdinal("Remark")),
        WaiverDate     = r.GetDateTime(r.GetOrdinal("WaiverDate")),
    };
}
