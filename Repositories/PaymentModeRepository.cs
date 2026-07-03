using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class PaymentModeRepository : IPaymentModeRepository
{
    private readonly IDbConnectionFactory _factory;
    public PaymentModeRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<PaymentMode>> GetAllAsync(string? status = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPaymentModes", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);
        var list = new List<PaymentMode>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new PaymentMode { Id = r.GetInt32(0), Name = r.GetString(1), Status = r.GetString(2) });
        return list;
    }

    public async Task<PaymentMode?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT Id,Name,Status FROM PaymentModes WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;
        return new PaymentMode { Id = r.GetInt32(0), Name = r.GetString(1), Status = r.GetString(2) };
    }

    public async Task<int> CreateAsync(PaymentMode pm)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreatePaymentMode", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Name",   pm.Name);
        cmd.Parameters.AddWithValue("@Status", pm.Status);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(PaymentMode pm)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdatePaymentMode", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",     pm.Id);
        cmd.Parameters.AddWithValue("@Name",   pm.Name);
        cmd.Parameters.AddWithValue("@Status", pm.Status);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeletePaymentMode", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }
}
