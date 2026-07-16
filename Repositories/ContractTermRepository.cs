using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class ContractTermRepository : IContractTermRepository
{
    private readonly IDbConnectionFactory _factory;
    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public ContractTermRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<ContractTermResponse>> GetByContractIdAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractTerms", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);

        var list = new List<ContractTermResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(Map(r));
        return list;
    }

    public async Task<IEnumerable<ContractTermResponse>> SaveAsync(string contractId, List<ContractTermItem> terms)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_SaveContractTerms", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        cmd.Parameters.AddWithValue("@TermsJson", JsonSerializer.Serialize(terms, _jsonOptions));

        var list = new List<ContractTermResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(Map(r));
        return list;
    }

    private static ContractTermResponse Map(SqlDataReader r) => new()
    {
        Id         = r.GetInt32(r.GetOrdinal("Id")),
        ContractId = r.GetString(r.GetOrdinal("ContractId")),
        PageNo     = r.GetInt32(r.GetOrdinal("PageNo")),
        TermNo     = r.GetInt32(r.GetOrdinal("TermNo")),
        TermText   = r.IsDBNull(r.GetOrdinal("TermText")) ? null : r.GetString(r.GetOrdinal("TermText")),
        CreatedAt  = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt  = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
