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
        await r.CloseAsync();

        // Har contract ke liye installments + transactions + monthly installments load karo
        foreach (var contract in list)
        {
            // Installments
            await using var connI = _factory.CreateConnection();
            await connI.OpenAsync();
            await using var cmdI = new SqlCommand("sp_GetOwnerInstallments", connI) { CommandType = CommandType.StoredProcedure };
            cmdI.Parameters.AddWithValue("@OcId",       contract.Id);
            cmdI.Parameters.AddWithValue("@PageNumber", 1);
            cmdI.Parameters.AddWithValue("@PageSize",   500);
            var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
            cmdI.Parameters.Add(totalParam);
            await using var rI = await cmdI.ExecuteReaderAsync();
            while (await rI.ReadAsync()) contract.Installments.Add(MapInstallment(rI));

            // Transactions
            contract.Transactions.AddRange(await GetTransactionsByContractIdAsync(contract.Id));

            // Monthly Installments
            contract.MonthlyInstallments.AddRange(await GetMonthlyInstallmentsByContractIdAsync(contract.Id));
        }

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
        cmd.Parameters.AddWithValue("@NoOfMonths",    contract.NoOfMonths);
        cmd.Parameters.AddWithValue("@InstallmentsJson", installmentsJson);
        cmd.Parameters.AddWithValue("@MonthlyInstallmentsJson", monthlyInstallmentsJson);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)contract.AddedBy ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> DeleteAsync(int id, int? deletedBy = null)    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOwnerContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    public async Task<int> RenewAsync(DTOs.RenewOwnerContractRequest request, int? userId)
    {
        var installmentsJson = System.Text.Json.JsonSerializer.Serialize(
            request.Installments.Select(i => new {
                No = i.No, Amount = i.Amount, DueDate = i.DueDate,
                PaymentMode = i.PaymentMode, ReferenceNo = i.ReferenceNo, Month = i.Month
            }));

        var monthlyInstallmentsJson = System.Text.Json.JsonSerializer.Serialize(
            request.MonthlyInstallments.Select(m => new {
                InstallmentNo = m.InstallmentNo, Amount = m.Amount, PaidAmount = m.PaidAmount,
                Balance = m.Balance, DueDate = m.DueDate, PaidDate = m.PaidDate,
                Status = m.Status, ExpenseId = m.ExpenseId, PaymentMode = m.PaymentMode,
                PaymentStatus = m.PaymentStatus, ReferenceNo = m.ReferenceNo, Month = m.Month
            }));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_RenewOwnerContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@OriginalOwnerContractId", request.OriginalOwnerContractId);
        cmd.Parameters.AddWithValue("@StartDate",               request.StartDate);
        cmd.Parameters.AddWithValue("@EndDate",                 (object?)request.EndDate                 ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractDate",            (object?)request.ContractDate            ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TotalAmount",             request.TotalAmount);
        cmd.Parameters.AddWithValue("@MonthlyRent",             request.MonthlyRent);
        cmd.Parameters.AddWithValue("@NoOfMonths",              request.NoOfMonths);
        cmd.Parameters.AddWithValue("@PaymentType",             request.PaymentType);
        cmd.Parameters.AddWithValue("@SecurityDeposit",         request.SecurityDeposit);
        cmd.Parameters.AddWithValue("@SecurityDepositPaid",     request.SecurityDepositPaid);
        cmd.Parameters.AddWithValue("@SecurityDepositPaidDate", (object?)request.SecurityDepositPaidDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ExpireOldContract",       request.ExpireOldContract ? 1 : 0);
        cmd.Parameters.AddWithValue("@Notes",                   (object?)request.Notes                   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@InstallmentsJson",        installmentsJson);
        cmd.Parameters.AddWithValue("@MonthlyInstallmentsJson", monthlyInstallmentsJson);
        cmd.Parameters.AddWithValue("@AddedBy",                 (object?)userId ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<IEnumerable<DTOs.OwnerContractRenewalResponse>> GetRenewalsAsync(int? originalOwnerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerContractRenewals", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@OriginalOwnerContractId", (object?)originalOwnerContractId ?? DBNull.Value);
        var list = new List<DTOs.OwnerContractRenewalResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new DTOs.OwnerContractRenewalResponse
            {
                Id                      = r.GetInt32(r.GetOrdinal("Id")),
                RenewalCode             = SafeStrR(r, "RenewalCode"),
                OriginalOwnerContractId = r.GetInt32(r.GetOrdinal("OriginalOwnerContractId")),
                OriginalOcCode          = SafeStrR(r, "OriginalOcCode"),
                NewOwnerContractId      = r.GetInt32(r.GetOrdinal("NewOwnerContractId")),
                NewOcCode               = SafeStrR(r, "NewOcCode"),
                CampId                  = r.GetInt32(r.GetOrdinal("CampId")),
                CampName                = SafeStrR(r, "CampName"),
                OwnerId                 = r.GetInt32(r.GetOrdinal("OwnerId")),
                OwnerName               = SafeStrR(r, "OwnerName"),
                TotalAmount             = r.GetDecimal(r.GetOrdinal("TotalAmount")),
                MonthlyRent             = SafeDecimal(r, "MonthlyRent"),
                NoOfMonths              = r.IsDBNull(r.GetOrdinal("NoOfMonths")) ? 0 : r.GetInt32(r.GetOrdinal("NoOfMonths")),
                StartDate               = r.GetDateTime(r.GetOrdinal("StartDate")).ToString("yyyy-MM-dd"),
                EndDate                 = r.IsDBNull(r.GetOrdinal("EndDate")) ? null : r.GetDateTime(r.GetOrdinal("EndDate")).ToString("yyyy-MM-dd"),
                ContractDate            = SafeStrR(r, "ContractDate"),
                ExpireOldContract       = !r.IsDBNull(r.GetOrdinal("ExpireOldContract")) && r.GetBoolean(r.GetOrdinal("ExpireOldContract")),
                Notes                   = SafeStrR(r, "Notes"),
                Status                  = SafeStrR(r, "Status"),
                CreatedAt               = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            });
        }
        return list;
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
        NoOfMonths              = r.IsDBNull(r.GetOrdinal("NoOfMonths")) ? 0 : r.GetInt32(r.GetOrdinal("NoOfMonths")),
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
