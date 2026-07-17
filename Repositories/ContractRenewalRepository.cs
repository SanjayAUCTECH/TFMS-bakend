using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class ContractRenewalRepository : IContractRenewalRepository
{
    private readonly IDbConnectionFactory _factory;
    public ContractRenewalRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<string> RenewAsync(RenewContractRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_RenewContract", conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 30
        };

        cmd.Parameters.AddWithValue("@OriginalContractId", r.OriginalContractId ?? "");
        cmd.Parameters.AddWithValue("@TenantId",           r.TenantId ?? 0);
        cmd.Parameters.AddWithValue("@CampIdsJson",        r.CampIds != null && r.CampIds.Count > 0
            ? JsonSerializer.Serialize(r.CampIds) : "[]");
        cmd.Parameters.AddWithValue("@StartDate",          r.StartDate ?? DateTime.Today);
        cmd.Parameters.AddWithValue("@Months",             r.Months ?? 12);
        cmd.Parameters.AddWithValue("@RoomIdsJson",        r.RoomIds != null && r.RoomIds.Count > 0
            ? JsonSerializer.Serialize(r.RoomIds) : "[]");
        cmd.Parameters.AddWithValue("@ContractType",       r.ContractType ?? "Monthly");
        cmd.Parameters.AddWithValue("@SecurityDeposit",    r.SecurityDeposit ?? 0);
        cmd.Parameters.AddWithValue("@InstallmentType",    r.InstallmentType ?? "monthly");
        cmd.Parameters.AddWithValue("@IssuedBy",           r.IssuedBy ?? "");
        cmd.Parameters.AddWithValue("@Notes",              r.Notes ?? "");
        cmd.Parameters.AddWithValue("@LessorAmount",       r.LessorAmount ?? 0);
        cmd.Parameters.AddWithValue("@MonthlyTotal",       (object?)r.MonthlyTotal ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractTotal",      (object?)r.ContractTotal ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RenewalType",        r.RenewalType ?? "Monthly");
        cmd.Parameters.AddWithValue("@ContractPropertyUsage", r.ContractPropertyUsage ?? "");
        cmd.Parameters.AddWithValue("@ContractBuildingName",  r.ContractBuildingName ?? "");
        cmd.Parameters.AddWithValue("@ContractPropertyType",  r.ContractPropertyType ?? "");
        cmd.Parameters.AddWithValue("@ContractLocation",      r.ContractLocation ?? "");
        cmd.Parameters.AddWithValue("@ContractPropertyNo",    r.ContractPropertyNo ?? "");
        cmd.Parameters.AddWithValue("@ContractPropertyArea",  r.ContractPropertyArea ?? "");
        cmd.Parameters.AddWithValue("@ContractPremisesNo",    r.ContractPremisesNo ?? "");
        cmd.Parameters.AddWithValue("@ContractPaymentMode",   r.ContractPaymentMode ?? "");
        cmd.Parameters.AddWithValue("@ContractPlotNo",        r.ContractPlotNo ?? "");
        cmd.Parameters.AddWithValue("@ContractMakaniNo",      r.ContractMakaniNo ?? "");
        cmd.Parameters.AddWithValue("@ExpireOldContract",     r.ExpireOldContract ?? true);

        var newContractId = new SqlParameter("@NewContractId", SqlDbType.NVarChar, -1)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newContractId);

        await cmd.ExecuteNonQueryAsync();
        return (string)newContractId.Value;
    }

    public async Task<IEnumerable<ContractRenewalResponse>> GetRenewalsAsync(string? contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractRenewals", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", (object?)contractId ?? DBNull.Value);

        var list = new List<ContractRenewalResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new ContractRenewalResponse
            {
                Id                 = r.GetInt32(r.GetOrdinal("Id")),
                OriginalContractId = r.GetString(r.GetOrdinal("OriginalContractId")),
                NewContractId      = r.GetString(r.GetOrdinal("NewContractId")),
                RenewalType        = r.IsDBNull(r.GetOrdinal("RenewalType")) ? "" : r.GetString(r.GetOrdinal("RenewalType")),
                RenewalDate        = r.IsDBNull(r.GetOrdinal("RenewalDate")) ? null : r.GetDateTime(r.GetOrdinal("RenewalDate")).ToString("yyyy-MM-dd"),
                NewStartDate       = r.IsDBNull(r.GetOrdinal("NewStartDate")) ? null : r.GetDateTime(r.GetOrdinal("NewStartDate")).ToString("yyyy-MM-dd"),
                NewEndDate         = r.IsDBNull(r.GetOrdinal("NewEndDate")) ? null : r.GetDateTime(r.GetOrdinal("NewEndDate")).ToString("yyyy-MM-dd"),
                NewMonths          = r.IsDBNull(r.GetOrdinal("NewMonths")) ? 0 : r.GetInt32(r.GetOrdinal("NewMonths")),
                NewMonthlyTotal    = r.IsDBNull(r.GetOrdinal("NewMonthlyTotal")) ? 0 : r.GetDecimal(r.GetOrdinal("NewMonthlyTotal")),
                NewContractTotal   = r.IsDBNull(r.GetOrdinal("NewContractTotal")) ? 0 : r.GetDecimal(r.GetOrdinal("NewContractTotal")),
                SecurityDeposit    = r.IsDBNull(r.GetOrdinal("SecurityDeposit")) ? 0 : r.GetDecimal(r.GetOrdinal("SecurityDeposit")),
                Notes              = r.IsDBNull(r.GetOrdinal("Notes")) ? null : r.GetString(r.GetOrdinal("Notes")),
                RenewedBy          = r.IsDBNull(r.GetOrdinal("RenewedBy")) ? null : r.GetString(r.GetOrdinal("RenewedBy")),
                Status             = r.IsDBNull(r.GetOrdinal("Status")) ? "" : r.GetString(r.GetOrdinal("Status")),
                TenantName         = r.IsDBNull(r.GetOrdinal("TenantName")) ? null : r.GetString(r.GetOrdinal("TenantName")),
                CreatedAt          = r.GetDateTime(r.GetOrdinal("CreatedAt")),
                UpdatedAt          = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
            });
        }
        return list;
    }
}
