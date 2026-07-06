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
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
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
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            if (contract == null) contract = MapContract(r);
            // second result set would be payments — handled if SP returns 2 sets
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
        SecurityDeposit = r.IsDBNull(r.GetOrdinal("SecurityDeposit")) ? 0 : r.GetDecimal(r.GetOrdinal("SecurityDeposit")),
        InstallmentType = r.IsDBNull(r.GetOrdinal("InstallmentType")) ? "monthly" : r.GetString(r.GetOrdinal("InstallmentType")),
        IssuedBy        = r.IsDBNull(r.GetOrdinal("IssuedBy"))        ? "" : r.GetString(r.GetOrdinal("IssuedBy")),
        Notes           = r.IsDBNull(r.GetOrdinal("Notes"))           ? "" : r.GetString(r.GetOrdinal("Notes")),
        LessorAmount    = r.IsDBNull(r.GetOrdinal("LessorAmount"))    ? 0 : r.GetDecimal(r.GetOrdinal("LessorAmount")),
        Status          = r.GetString(r.GetOrdinal("Status")),
        CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt       = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
