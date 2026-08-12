using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class PartnerTransRepository : IPartnerTransRepository
{
    private readonly IDbConnectionFactory _factory;

    public PartnerTransRepository(IDbConnectionFactory factory) => _factory = factory;

    // ──────────────────────────────────────────────
    // Get all transactions for a partner
    // ──────────────────────────────────────────────
    public async Task<IEnumerable<PartnerTrans>> GetByPartnerIdAsync(int partnerId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand(
            @"SELECT Id, PartnerId, PaymentMode, [Type], AccountHead,
                     Amount, AccountId, Remark,
                     AddedBy, UpdatedBy, IsDeletedBy, IsDeleted,
                     CreatedAt, UpdatedAt
              FROM PartnerTrans
              WHERE PartnerId = @PartnerId AND IsDeleted = 0
              ORDER BY CreatedAt DESC", conn);

        cmd.Parameters.AddWithValue("@PartnerId", partnerId);

        var list = new List<PartnerTrans>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    // ──────────────────────────────────────────────
    // Get single transaction by Id
    // ──────────────────────────────────────────────
    public async Task<PartnerTrans?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand(
            @"SELECT Id, PartnerId, PaymentMode, [Type], AccountHead,
                     Amount, AccountId, Remark,
                     AddedBy, UpdatedBy, IsDeletedBy, IsDeleted,
                     CreatedAt, UpdatedAt
              FROM PartnerTrans
              WHERE Id = @Id AND IsDeleted = 0", conn);

        cmd.Parameters.AddWithValue("@Id", id);

        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    // ──────────────────────────────────────────────
    // Mapper
    // ──────────────────────────────────────────────
    private static PartnerTrans Map(SqlDataReader r) => new()
    {
        Id          = r.GetInt32(r.GetOrdinal("Id")),
        PartnerId   = r.GetInt32(r.GetOrdinal("PartnerId")),
        PaymentMode = r.IsDBNull(r.GetOrdinal("PaymentMode")) ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
        Type        = r.IsDBNull(r.GetOrdinal("Type"))        ? "" : r.GetString(r.GetOrdinal("Type")),
        AccountHead = r.IsDBNull(r.GetOrdinal("AccountHead")) ? "" : r.GetString(r.GetOrdinal("AccountHead")),
        Amount      = r.GetDecimal(r.GetOrdinal("Amount")),
        AccountId   = r.IsDBNull(r.GetOrdinal("AccountId"))   ? null : r.GetString(r.GetOrdinal("AccountId")),
        Remark      = r.IsDBNull(r.GetOrdinal("Remark"))      ? "" : r.GetString(r.GetOrdinal("Remark")),
        AddedBy     = r.IsDBNull(r.GetOrdinal("AddedBy"))     ? null : r.GetInt32(r.GetOrdinal("AddedBy")),
        UpdatedBy   = r.IsDBNull(r.GetOrdinal("UpdatedBy"))   ? null : r.GetInt32(r.GetOrdinal("UpdatedBy")),
        IsDeletedBy = r.IsDBNull(r.GetOrdinal("IsDeletedBy")) ? null : r.GetInt32(r.GetOrdinal("IsDeletedBy")),
        IsDeleted   = r.GetBoolean(r.GetOrdinal("IsDeleted")),
        CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt   = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
