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

        // Load monthly installments
        contract.MonthlyInstallments.AddRange(await GetMonthlyInstallmentsByContractIdAsync(id));

        return contract;
    }

    public async Task<IEnumerable<OwnerMonthlyContractInstallment>> GetMonthlyInstallmentsByContractIdAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "SELECT Id, MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId, " +
            "InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate, " +
            "Status, ExpenseId, PaymentMode, PaymentStatus, " +
            "ISNULL(ReferenceNo,'') AS ReferenceNo, ISNULL(Month,'') AS Month, CreatedAt, UpdatedAt " +
            "FROM OwnerMonthlyContractInstallments WHERE OwnerContractId = @OwnerContractId ORDER BY InstallmentNo",
            conn);
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);
        var list = new List<OwnerMonthlyContractInstallment>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapMonthlyInstallment(r));
        return list;
    }

    public async Task<IEnumerable<OwnerTransaction>> GetTransactionsByContractIdAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "SELECT Id, TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName, " +
            "Type, Amount, Date, Description, InstallmentNos, ExpenseId, " +
            "ISNULL(ReferenceNo,'') AS ReferenceNo, ISNULL(PaymentMode,'') AS PaymentMode, CreatedAt " +
            "FROM OwnerTransactions WHERE OwnerContractId = @OwnerContractId ORDER BY Date, Id",
            conn);
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);
        var list = new List<OwnerTransaction>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapTransaction(r));
        return list;
    }

    public async Task<int> CreateAsync(OwnerContract contract, string installmentsJson, string monthlyInstallmentsJson)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateOwnerContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@CampId",           contract.CampId);
        cmd.Parameters.AddWithValue("@OwnerId",          contract.OwnerId);
        cmd.Parameters.AddWithValue("@PaymentType",      contract.PaymentType);
        cmd.Parameters.AddWithValue("@TotalAmount",      contract.TotalAmount);
        cmd.Parameters.AddWithValue("@StartDate",        contract.StartDate.ToString("yyyy-MM-dd"));
        cmd.Parameters.AddWithValue("@EndDate",          (object?)contract.EndDate?.ToString("yyyy-MM-dd") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SecurityDeposit",  contract.SecurityDeposit);
        cmd.Parameters.AddWithValue("@SecurityDepositPaid", contract.SecurityDepositPaid);
        cmd.Parameters.AddWithValue("@SecurityDepositPaidDate", (object?)contract.SecurityDepositPaidDate?.ToString("yyyy-MM-dd") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractDate",  (object?)contract.ContractDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@MonthlyRent",   contract.MonthlyRent);
        cmd.Parameters.AddWithValue("@InstallmentsJson", installmentsJson);
        cmd.Parameters.AddWithValue("@MonthlyInstallmentsJson", monthlyInstallmentsJson);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)contract.AddedBy ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> DeleteAsync(int id, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOwnerContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
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
        EndDate     = r.IsDBNull(r.GetOrdinal("EndDate")) ? null : r.GetDateTime(r.GetOrdinal("EndDate")),
        SecurityDeposit         = SafeDecimal(r, "SecurityDeposit"),
        SecurityDepositPaid     = SafeDecimal(r, "SecurityDepositPaid"),
        SecurityDepositPaidDate = r.IsDBNull(r.GetOrdinal("SecurityDepositPaidDate")) ? null : r.GetDateTime(r.GetOrdinal("SecurityDepositPaidDate")),
        ContractDate            = SafeStrR(r, "ContractDate"),
        MonthlyRent             = SafeDecimal(r, "MonthlyRent"),
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
        ExpenseId       = null,
        PaymentMode     = SafeStrR(r, "PaymentMode"),
        ReferenceNo     = SafeStrR(r, "ReferenceNo"),
        Remarks         = SafeStrR(r, "Remarks"),
        Month           = SafeStrR(r, "Month"),
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
        ReferenceNo     = SafeStrR(r, "ReferenceNo"),
        PaymentMode     = SafeStrR(r, "PaymentMode"),
        CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
    };

    private static OwnerMonthlyContractInstallment MapMonthlyInstallment(SqlDataReader r) => new()
    {
        Id                           = r.GetInt32(r.GetOrdinal("Id")),
        MonthlyContractInstallmentId = r.IsDBNull(r.GetOrdinal("MonthlyContractInstallmentId")) ? "" : r.GetString(r.GetOrdinal("MonthlyContractInstallmentId")),
        OwnerContractId              = r.GetInt32(r.GetOrdinal("OwnerContractId")),
        OwnerId                      = r.GetInt32(r.GetOrdinal("OwnerId")),
        CampId                       = r.GetInt32(r.GetOrdinal("CampId")),
        InstallmentNo                = r.GetInt32(r.GetOrdinal("InstallmentNo")),
        Amount                       = r.GetDecimal(r.GetOrdinal("Amount")),
        PaidAmount                   = r.GetDecimal(r.GetOrdinal("PaidAmount")),
        Balance                      = r.GetDecimal(r.GetOrdinal("Balance")),
        DueDate                      = r.GetDateTime(r.GetOrdinal("DueDate")),
        PaidDate                     = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")),
        Status                       = r.IsDBNull(r.GetOrdinal("Status")) ? "" : r.GetString(r.GetOrdinal("Status")),
        ExpenseId                    = r.IsDBNull(r.GetOrdinal("ExpenseId")) ? null : r.GetInt32(r.GetOrdinal("ExpenseId")),
        PaymentMode                  = r.IsDBNull(r.GetOrdinal("PaymentMode")) ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
        PaymentStatus                = r.IsDBNull(r.GetOrdinal("PaymentStatus")) ? "" : r.GetString(r.GetOrdinal("PaymentStatus")),
        ReferenceNo                  = SafeStrR(r, "ReferenceNo"),
        Month                        = SafeStrR(r, "Month"),
        CreatedAt                    = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt                    = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static string SafeStrR(SqlDataReader r, string col)
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? "" : r.GetString(o); } catch { return ""; }
    }
    private static decimal SafeDecimal(SqlDataReader r, string col)
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? 0 : r.GetDecimal(o); } catch { return 0; }
    }
}
