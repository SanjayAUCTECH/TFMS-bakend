using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class ContractCancellationRepository : IContractCancellationRepository
{
    private readonly IDbConnectionFactory _factory;
    public ContractCancellationRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<int> CancelAsync(CancelContractRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CancelContract", conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 15
        };

        cmd.Parameters.AddWithValue("@ContractId", r.ContractId ?? "");
        cmd.Parameters.AddWithValue("@CancellationDate",
            string.IsNullOrEmpty(r.CancellationDate) ? (object)DBNull.Value : DateTime.Parse(r.CancellationDate));
        cmd.Parameters.AddWithValue("@CancellationReason", (object?)r.CancellationReason ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RefundAmount", r.RefundAmount ?? 0);
        cmd.Parameters.AddWithValue("@PenaltyAmount", r.PenaltyAmount ?? 0);
        cmd.Parameters.AddWithValue("@SettlementAmount", r.SettlementAmount ?? 0);
        cmd.Parameters.AddWithValue("@CancelledBy", (object?)r.CancelledBy ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Notes", (object?)r.Notes ?? DBNull.Value);

        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);

        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<IEnumerable<ContractCancellationResponse>> GetAllAsync(string? contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractCancellations", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ContractId", (object?)contractId ?? DBNull.Value);

        var list = new List<ContractCancellationResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new ContractCancellationResponse
            {
                Id                 = r.GetInt32(r.GetOrdinal("Id")),
                ContractId         = r.GetString(r.GetOrdinal("ContractId")),
                TenantId           = r.IsDBNull(r.GetOrdinal("TenantId")) ? 0 : r.GetInt32(r.GetOrdinal("TenantId")),
                TenantName         = r.IsDBNull(r.GetOrdinal("TenantName")) ? null : r.GetString(r.GetOrdinal("TenantName")),
                CancellationDate   = r.IsDBNull(r.GetOrdinal("CancellationDate")) ? null : r.GetDateTime(r.GetOrdinal("CancellationDate")).ToString("yyyy-MM-dd"),
                CancellationReason = r.IsDBNull(r.GetOrdinal("CancellationReason")) ? null : r.GetString(r.GetOrdinal("CancellationReason")),
                RefundAmount       = r.IsDBNull(r.GetOrdinal("RefundAmount")) ? 0 : r.GetDecimal(r.GetOrdinal("RefundAmount")),
                PenaltyAmount      = r.IsDBNull(r.GetOrdinal("PenaltyAmount")) ? 0 : r.GetDecimal(r.GetOrdinal("PenaltyAmount")),
                SettlementAmount   = r.IsDBNull(r.GetOrdinal("SettlementAmount")) ? 0 : r.GetDecimal(r.GetOrdinal("SettlementAmount")),
                CancelledBy        = r.IsDBNull(r.GetOrdinal("CancelledBy")) ? null : r.GetString(r.GetOrdinal("CancelledBy")),
                Notes              = r.IsDBNull(r.GetOrdinal("Notes")) ? null : r.GetString(r.GetOrdinal("Notes")),
                Status             = r.IsDBNull(r.GetOrdinal("Status")) ? "" : r.GetString(r.GetOrdinal("Status")),
                CreatedAt          = r.GetDateTime(r.GetOrdinal("CreatedAt")),
                UpdatedAt          = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
            });
        }
        return list;
    }
}
