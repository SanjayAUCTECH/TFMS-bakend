using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class OwnerContractRepository : IOwnerContractRepository
{
    private readonly IDbConnectionFactory _factory;
    public OwnerContractRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<OwnerContract>> GetByCampAsync(int? campId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerContracts", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@CampId", (object?)campId ?? DBNull.Value);
        var list = new List<OwnerContract>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapContract(r));
        return list;
    }

    public async Task<OwnerContract?> GetByIdAsync(int id)
    {
        var all = await GetByCampAsync(null);
        var contract = all.FirstOrDefault(c => c.Id == id);
        if (contract == null) return null;

        // Load installments
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerInstallments", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@OwnerContractId", id);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) contract.Installments.Add(MapInstallment(r));
        return contract;
    }

    public async Task<int> CreateAsync(OwnerContract contract, string installmentsJson)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateOwnerContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@CampId",           contract.CampId);
        cmd.Parameters.AddWithValue("@OwnerId",          contract.OwnerId);
        cmd.Parameters.AddWithValue("@PaymentType",      contract.PaymentType);
        cmd.Parameters.AddWithValue("@TotalAmount",      contract.TotalAmount);
        cmd.Parameters.AddWithValue("@StartDate",        contract.StartDate.ToString("yyyy-MM-dd"));
        cmd.Parameters.AddWithValue("@InstallmentsJson", installmentsJson);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOwnerContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    private static OwnerContract MapContract(SqlDataReader r) => new()
    {
        Id          = r.GetInt32(r.GetOrdinal("Id")),
        OcCode      = r.GetString(r.GetOrdinal("OcCode")),
        CampId      = r.GetInt32(r.GetOrdinal("CampId")),
        CampName    = r.IsDBNull(r.GetOrdinal("CampName"))  ? "" : r.GetString(r.GetOrdinal("CampName")),
        OwnerId     = r.GetInt32(r.GetOrdinal("OwnerId")),
        OwnerName   = r.IsDBNull(r.GetOrdinal("OwnerName")) ? "" : r.GetString(r.GetOrdinal("OwnerName")),
        OwnerCode   = r.IsDBNull(r.GetOrdinal("OwnerCode")) ? "" : r.GetString(r.GetOrdinal("OwnerCode")),
        PaymentType = r.GetString(r.GetOrdinal("PaymentType")),
        TotalAmount = r.GetDecimal(r.GetOrdinal("TotalAmount")),
        PaidAmount  = r.GetDecimal(r.GetOrdinal("PaidAmount")),
        Balance     = r.GetDecimal(r.GetOrdinal("Balance")),
        StartDate   = r.GetDateTime(r.GetOrdinal("StartDate")),
        Status      = r.GetString(r.GetOrdinal("Status")),
        CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
    };

    private static OwnerInstallment MapInstallment(SqlDataReader r) => new()
    {
        Id              = r.GetInt32(r.GetOrdinal("Id")),
        OwnerContractId = r.GetInt32(r.GetOrdinal("OwnerContractId")),
        No              = r.GetInt32(r.GetOrdinal("No")),
        Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
        PaidAmount      = r.GetDecimal(r.GetOrdinal("PaidAmount")),
        DueDate         = r.GetDateTime(r.GetOrdinal("DueDate")),
        PaidDate        = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")),
        Status          = r.GetString(r.GetOrdinal("Status")),
        ExpenseId       = r.IsDBNull(r.GetOrdinal("ExpenseId")) ? null : r.GetInt32(r.GetOrdinal("ExpenseId")),
    };
}
