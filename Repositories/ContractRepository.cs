using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class ContractRepository : IContractRepository
{
    private readonly IDbConnectionFactory _factory;
    public ContractRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Contract> Data, int TotalRecords)> GetAllAsync(ContractListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContracts", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",      (object?)request.TenantId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",      (object?)request.DateFrom  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",        (object?)request.DateTo    ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Contract>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapContract(r));
        await r.CloseAsync();
        int totalCount = (int)(total.Value == DBNull.Value ? 0 : total.Value);

        // Load RoomIds for each contract
        if (list.Count > 0) {
            var contractIds = string.Join(",", list.Select(c => $"'{c.ContractId}'"));
            await using var cmd2 = new SqlCommand(
                $"SELECT ContractId, RoomId FROM ContractRooms WHERE ContractId IN ({contractIds})", conn);
            await using var r2 = await cmd2.ExecuteReaderAsync();
            var roomMap = new Dictionary<string, List<int>>();
            while (await r2.ReadAsync()) {
                var cid = r2.GetString(0);
                var rid = r2.GetInt32(1);
                if (!roomMap.ContainsKey(cid)) roomMap[cid] = new();
                roomMap[cid].Add(rid);
            }
            foreach (var c in list)
                c.RoomIds = roomMap.TryGetValue(c.ContractId, out var ids) ? ids : new();
        }

        return (list, totalCount);
    }

    public async Task<Contract?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await ReadContractWithPayments(cmd);
    }

    public async Task<Contract?> GetByContractIdAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractByContractId", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        return await ReadContractWithPayments(cmd);
    }

    public async Task<string> CreateAsync(Contract contract)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TenantId",        contract.TenantId);
        cmd.Parameters.AddWithValue("@CampId",          contract.CampId);
        cmd.Parameters.AddWithValue("@StartDate",       contract.StartDate);
        cmd.Parameters.AddWithValue("@Months",          contract.Months);
        var roomIdsJson = System.Text.Json.JsonSerializer.Serialize(contract.RoomIds);
        cmd.Parameters.AddWithValue("@RoomIdsJson",     roomIdsJson);
        cmd.Parameters.AddWithValue("@SecurityDeposit", contract.SecurityDeposit);
        cmd.Parameters.AddWithValue("@InstallmentType", contract.InstallmentType);
        cmd.Parameters.AddWithValue("@IssuedBy",        contract.IssuedBy);
        cmd.Parameters.AddWithValue("@Notes",           contract.Notes);
        cmd.Parameters.AddWithValue("@LessorAmount",    contract.LessorAmount);
        var newContractId = new SqlParameter("@NewContractId", SqlDbType.NVarChar, 20) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newContractId);
        await cmd.ExecuteNonQueryAsync();
        return (string)newContractId.Value;
    }

    public async Task<bool> UpdateStatusAsync(string contractId, string status)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateContractStatus", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        cmd.Parameters.AddWithValue("@Status",     status);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> UpdateContractAsync(UpdateContractRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId",   request.ContractId);
        cmd.Parameters.AddWithValue("@TenantId",     request.TenantId);
        cmd.Parameters.AddWithValue("@StartDate",    request.StartDate);
        cmd.Parameters.AddWithValue("@Months",       request.Months);
        cmd.Parameters.AddWithValue("@RoomIdsJson",  System.Text.Json.JsonSerializer.Serialize(request.RoomIds));
        cmd.Parameters.AddWithValue("@LessorAmount", request.LessorAmount);
        cmd.Parameters.AddWithValue("@Notes",        request.Notes ?? "");
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    public async Task<bool> UpdateScheduleAsync(string contractId, string scheduleJson)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdatePaymentSchedule", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId",   contractId);
        cmd.Parameters.AddWithValue("@ScheduleJson", scheduleJson);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    private static async Task<Contract?> ReadContractWithPayments(SqlCommand cmd)
    {
        Contract? contract = null;
        var roomIds  = new HashSet<int>();
        var payments = new List<Payment>();

        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            // Map contract once
            if (contract == null) contract = MapContract(r);

            // RoomId column
            try {
                var roomIdOrd = r.GetOrdinal("RoomId");
                if (!r.IsDBNull(roomIdOrd))
                    roomIds.Add(r.GetInt32(roomIdOrd));
            } catch { /* column may not exist */ }

            // Payment columns
            try {
                var payIdOrd = r.GetOrdinal("PayId");
                if (!r.IsDBNull(payIdOrd)) {
                    var payId = r.GetInt32(payIdOrd);
                    if (!payments.Any(p => p.Id == payId)) {
                        payments.Add(new Payment {
                            Id            = payId,
                            ContractId    = r.GetString(r.GetOrdinal("ContractId")),
                            InstallmentNo = r.GetInt32(r.GetOrdinal("InstallmentNo")),
                            Amount        = r.GetDecimal(r.GetOrdinal("PayAmount")),
                            DueDate       = r.GetDateTime(r.GetOrdinal("DueDate")),
                            PaidAmount    = r.GetDecimal(r.GetOrdinal("PaidAmount")),
                            PaidDate      = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")),
                            Status        = r.GetString(r.GetOrdinal("PayStatus")),
                            PaymentMode   = r.IsDBNull(r.GetOrdinal("PaymentMode")) ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
                        });
                    }
                }
            } catch { /* column may not exist */ }
        }

        if (contract != null) {
            contract.RoomIds  = roomIds.ToList();
            contract.Payments = payments;
        }
        return contract;
    }

    private static Contract MapContract(SqlDataReader r) => new()
    {
        Id              = r.GetInt32(r.GetOrdinal("Id")),
        ContractId      = r.GetString(r.GetOrdinal("ContractId")),
        TenantId        = r.GetInt32(r.GetOrdinal("TenantId")),
        TenantName      = r.IsDBNull(r.GetOrdinal("TenantName"))    ? "" : r.GetString(r.GetOrdinal("TenantName")),
        CampId          = r.GetInt32(r.GetOrdinal("CampId")),
        CampName        = r.IsDBNull(r.GetOrdinal("CampName"))      ? "" : r.GetString(r.GetOrdinal("CampName")),
        StartDate       = r.GetDateTime(r.GetOrdinal("StartDate")),
        Months          = r.GetInt32(r.GetOrdinal("Months")),
        EndDate         = r.GetDateTime(r.GetOrdinal("EndDate")),
        MonthlyTotal    = r.GetDecimal(r.GetOrdinal("MonthlyTotal")),
        ContractTotal   = r.GetDecimal(r.GetOrdinal("ContractTotal")),
        SecurityDeposit = HasColumn(r,"SecurityDeposit") && !r.IsDBNull(r.GetOrdinal("SecurityDeposit")) ? r.GetDecimal(r.GetOrdinal("SecurityDeposit")) : 0,
        InstallmentType = HasColumn(r,"InstallmentType") && !r.IsDBNull(r.GetOrdinal("InstallmentType")) ? r.GetString(r.GetOrdinal("InstallmentType")) : "monthly",
        IssuedBy        = HasColumn(r,"IssuedBy")        && !r.IsDBNull(r.GetOrdinal("IssuedBy"))        ? r.GetString(r.GetOrdinal("IssuedBy"))        : "",
        Notes           = HasColumn(r,"Notes")           && !r.IsDBNull(r.GetOrdinal("Notes"))           ? r.GetString(r.GetOrdinal("Notes"))           : "",
        LessorAmount    = HasColumn(r,"LessorAmount")    && !r.IsDBNull(r.GetOrdinal("LessorAmount"))    ? r.GetDecimal(r.GetOrdinal("LessorAmount"))    : 0,
        Status          = r.GetString(r.GetOrdinal("Status")),
        TotalPaid         = HasColumn(r, "TotalPaid")           && !r.IsDBNull(r.GetOrdinal("TotalPaid"))
                            ? Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalPaid"))) : 0,
        TotalDue          = HasColumn(r, "TotalDue")            && !r.IsDBNull(r.GetOrdinal("TotalDue"))
                            ? Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalDue")))  : 0,
        LastPaymentAmount = HasColumn(r, "LastPaymentAmount")   && !r.IsDBNull(r.GetOrdinal("LastPaymentAmount"))
                            ? Convert.ToDecimal(r.GetValue(r.GetOrdinal("LastPaymentAmount"))) : (decimal?)null,
        LastPaymentDate   = HasColumn(r, "LastPaymentDate")     && !r.IsDBNull(r.GetOrdinal("LastPaymentDate"))
                            ? r.GetDateTime(r.GetOrdinal("LastPaymentDate")) : (DateTime?)null,
        CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt       = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static bool HasColumn(SqlDataReader r, string name)
    {
        for (int i = 0; i < r.FieldCount; i++)
            if (r.GetName(i).Equals(name, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }
}
