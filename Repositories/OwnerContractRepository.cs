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

        // Load installments — SP requires @OcId and @TotalRecords OUTPUT
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerInstallments", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@OcId", id);
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize", 500);
        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) contract.Installments.Add(MapInstallment(r));

        // Load transactions
        contract.Transactions.AddRange(await GetTransactionsByContractIdAsync(id));

        return contract;
    }

    public async Task<IEnumerable<OwnerTransaction>> GetTransactionsByContractIdAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "SELECT Id, TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName, " +
            "Type, Amount, Date, Description, InstallmentNos, ExpenseId, CreatedAt " +
            "FROM OwnerTransactions WHERE OwnerContractId = @OwnerContractId ORDER BY Date, Id",
            conn);
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);
        var list = new List<OwnerTransaction>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapTransaction(r));
        return list;
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
        No              = r.GetInt32(r.GetOrdinal("InstallmentNo")),
        Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
        PaidAmount      = r.GetDecimal(r.GetOrdinal("PaidAmount")),
        DueDate         = r.GetDateTime(r.GetOrdinal("DueDate")),
        PaidDate        = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")),
        Status          = r.GetString(r.GetOrdinal("Status")),
        ExpenseId       = null,  // not returned by sp_GetOwnerInstallments
    };

    private static OwnerTransaction MapTransaction(SqlDataReader r) => new()
    {
        Id              = r.GetInt32(r.GetOrdinal("Id")),
        TxnCode         = r.IsDBNull(r.GetOrdinal("TxnCode"))        ? "" : r.GetString(r.GetOrdinal("TxnCode")),
        OwnerContractId = r.GetInt32(r.GetOrdinal("OwnerContractId")),
        OcCode          = r.IsDBNull(r.GetOrdinal("OcCode"))          ? "" : r.GetString(r.GetOrdinal("OcCode")),
        CampId          = r.GetInt32(r.GetOrdinal("CampId")),
        CampName        = r.IsDBNull(r.GetOrdinal("CampName"))        ? "" : r.GetString(r.GetOrdinal("CampName")),
        OwnerId         = r.GetInt32(r.GetOrdinal("OwnerId")),
        OwnerName       = r.IsDBNull(r.GetOrdinal("OwnerName"))       ? "" : r.GetString(r.GetOrdinal("OwnerName")),
        Type            = r.IsDBNull(r.GetOrdinal("Type"))            ? "" : r.GetString(r.GetOrdinal("Type")),
        Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
        Date            = r.GetDateTime(r.GetOrdinal("Date")),
        Description     = r.IsDBNull(r.GetOrdinal("Description"))     ? "" : r.GetString(r.GetOrdinal("Description")),
        InstallmentNos  = r.IsDBNull(r.GetOrdinal("InstallmentNos"))  ? "" : r.GetString(r.GetOrdinal("InstallmentNos")),
        ExpenseId       = r.IsDBNull(r.GetOrdinal("ExpenseId"))       ? null : r.GetInt32(r.GetOrdinal("ExpenseId")),
        CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
    };
}
