using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class OwnerContractCancellationRepository : IOwnerContractCancellationRepository
{
    private readonly IDbConnectionFactory _factory;
    public OwnerContractCancellationRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<int> CancelAsync(CancelOwnerContractRequest request, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CancelOwnerContract", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 15
        };
        cmd.Parameters.AddWithValue("@OwnerContractId",  request.OwnerContractId);
        cmd.Parameters.AddWithValue("@CancellationDate", request.CancellationDate);
        cmd.Parameters.AddWithValue("@Remarks",          (object?)request.Remarks     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CancelledBy",      (object?)request.CancelledBy ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CancelledByUserId",(object?)userId               ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<IEnumerable<OwnerContractCancellationResponse>> GetAllAsync(int? ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerContractCancellations", conn)
            { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@OwnerContractId", (object?)ownerContractId ?? DBNull.Value);
        var list = new List<OwnerContractCancellationResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new OwnerContractCancellationResponse
            {
                Id               = r.GetInt32(r.GetOrdinal("Id")),
                CancellationCode = r.IsDBNull(r.GetOrdinal("CancellationCode")) ? "" : r.GetString(r.GetOrdinal("CancellationCode")),
                OwnerContractId  = r.GetInt32(r.GetOrdinal("OwnerContractId")),
                OcCode           = r.IsDBNull(r.GetOrdinal("OcCode"))    ? "" : r.GetString(r.GetOrdinal("OcCode")),
                CampId           = r.IsDBNull(r.GetOrdinal("CampId"))    ? 0  : r.GetInt32(r.GetOrdinal("CampId")),
                CampName         = r.IsDBNull(r.GetOrdinal("CampName"))  ? "" : r.GetString(r.GetOrdinal("CampName")),
                OwnerId          = r.IsDBNull(r.GetOrdinal("OwnerId"))   ? 0  : r.GetInt32(r.GetOrdinal("OwnerId")),
                OwnerName        = r.IsDBNull(r.GetOrdinal("OwnerName")) ? "" : r.GetString(r.GetOrdinal("OwnerName")),
                CancellationDate = r.IsDBNull(r.GetOrdinal("CancellationDate")) ? "" : r.GetDateTime(r.GetOrdinal("CancellationDate")).ToString("yyyy-MM-dd"),
                Remarks          = r.IsDBNull(r.GetOrdinal("Remarks"))         ? null : r.GetString(r.GetOrdinal("Remarks")),
                CancelledBy      = r.IsDBNull(r.GetOrdinal("CancelledBy"))     ? null : r.GetString(r.GetOrdinal("CancelledBy")),
                CancelledByUserId= r.IsDBNull(r.GetOrdinal("CancelledByUserId"))? null : r.GetInt32(r.GetOrdinal("CancelledByUserId")),
                Status           = r.IsDBNull(r.GetOrdinal("Status"))          ? "" : r.GetString(r.GetOrdinal("Status")),
                CreatedAt        = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            });
        }
        return list;
    }
}
