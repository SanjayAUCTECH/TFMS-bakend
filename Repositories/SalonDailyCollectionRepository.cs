using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class SalonDailyCollectionRepository : ISalonDailyCollectionRepository
{
    private readonly IDbConnectionFactory _factory;
    public SalonDailyCollectionRepository(IDbConnectionFactory factory) => _factory = factory;

    // ══════════════════════════════════════════════════════════
    //  SDCollection
    // ══════════════════════════════════════════════════════════

    public async Task<(IEnumerable<SDCollection> Data, int TotalRecords)> GetAllCollectionsAsync(
        SDCollectionListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSDCollection", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SalonId",    (object?)request.SalonId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@StaffId",    (object?)request.StaffId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)request.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo) ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list = new List<SDCollection>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapCollection(r));
        await r.CloseAsync();
        return (list, totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value);
    }

    public async Task<SDCollection?> GetCollectionByIdAsync(int collectionId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetSDCollectionById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@CollectionId", collectionId);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapCollection(r) : null;
    }

    public async Task<int> BulkCreateCollectionsAsync(List<SDCollectionItem> items, string? addedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Build JSON array for SP
        var jsonArray = JsonSerializer.Serialize(items.Select(i => new
        {
            date        = i.Date.ToString("yyyy-MM-dd"),
            salonId     = i.SalonId,
            staffId     = i.StaffId,
            headId      = i.HeadId,
            mode        = i.Mode,
            amount      = i.Amount,
            description = i.Description,
            status      = i.Status
        }));

        await using var cmd = new SqlCommand("sp_BulkCreateSDCollection", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@CollectionsJson", jsonArray);
        cmd.Parameters.AddWithValue("@AddedBy",         (object?)addedBy ?? DBNull.Value);

        var countParam = new SqlParameter("@InsertedCount", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(countParam);

        await cmd.ExecuteNonQueryAsync();
        return countParam.Value == DBNull.Value ? 0 : (int)countParam.Value;
    }

    public async Task<bool> UpdateCollectionAsync(SDCollection item)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateSDCollection", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@CollectionId", item.CollectionId);
        cmd.Parameters.AddWithValue("@Date",         item.Date);
        cmd.Parameters.AddWithValue("@SalonId",      item.SalonId);
        cmd.Parameters.AddWithValue("@StaffId",      (object?)item.StaffId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@HeadId",       (object?)item.HeadId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode",         (object?)item.Mode      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Amount",       (object?)item.Amount    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description",  (object?)item.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",       (object?)item.Status    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UpdatedBy",    (object?)item.UpdatedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteCollectionAsync(int collectionId, string? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteSDCollection", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@CollectionId", collectionId);
        cmd.Parameters.AddWithValue("@DeletedBy",    (object?)deletedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // ══════════════════════════════════════════════════════════
    //  SDExpence
    // ══════════════════════════════════════════════════════════

    public async Task<(IEnumerable<SDExpence> Data, int TotalRecords)> GetAllExpencesAsync(
        SDExpenceListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSDExpence", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@PageNumber",  request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",    request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)request.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SalonId",     (object?)request.SalonId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ExpenceType", (object?)request.ExpenceType ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      (object?)request.Status      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo) ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list = new List<SDExpence>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapExpence(r));
        await r.CloseAsync();
        return (list, totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value);
    }

    public async Task<SDExpence?> GetExpenceByIdAsync(int expenceId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetSDExpenceById", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ExpenceId", expenceId);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapExpence(r) : null;
    }

    public async Task<int> BulkCreateExpencesAsync(List<SDExpenceItem> items, string? addedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var jsonArray = JsonSerializer.Serialize(items.Select(i => new
        {
            date          = i.Date.ToString("yyyy-MM-dd"),
            salonId       = i.SalonId,
            headId        = i.HeadId,
            expenceType   = i.ExpenceType,
            mode          = i.Mode,
            amount        = i.Amount,
            description   = i.Description,
            status        = i.Status
        }));

        await using var cmd = new SqlCommand("sp_BulkCreateSDExpence", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ExpencesJson", jsonArray);
        cmd.Parameters.AddWithValue("@AddedBy",      (object?)addedBy ?? DBNull.Value);

        var countParam = new SqlParameter("@InsertedCount", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(countParam);

        await cmd.ExecuteNonQueryAsync();
        return countParam.Value == DBNull.Value ? 0 : (int)countParam.Value;
    }

    public async Task<bool> UpdateExpenceAsync(SDExpence item)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateSDExpence", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ExpenceId",     item.ExpenceId);
        cmd.Parameters.AddWithValue("@Date",          item.Date);
        cmd.Parameters.AddWithValue("@SalonId",       item.SalonId);
        cmd.Parameters.AddWithValue("@HeadId",        (object?)item.HeadId        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ExpenceType",   (object?)item.ExpenceType   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode",          (object?)item.Mode          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Amount",        (object?)item.Amount        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description",   (object?)item.Description   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",        (object?)item.Status        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UpdatedBy",     (object?)item.UpdatedBy     ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteExpenceAsync(int expenceId, string? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteSDExpence", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ExpenceId", expenceId);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // ── Mappers ────────────────────────────────────────────────
    private static SDCollection MapCollection(SqlDataReader r)
    {
        int ordStaff     = r.GetOrdinal("StaffId");
        int ordStaffName = r.GetOrdinal("StaffName");
        int ordHead      = r.GetOrdinal("HeadId");
        int ordHeadName  = r.GetOrdinal("HeadName");
        int ordMode      = r.GetOrdinal("Mode");
        int ordAmount    = r.GetOrdinal("Amount");
        int ordDesc      = r.GetOrdinal("Description");
        int ordStatus    = r.GetOrdinal("Status");
        int ordUpdatedAt = r.GetOrdinal("UpdatedAt");
        return new SDCollection
        {
            CollectionId = r.GetInt32(r.GetOrdinal("CollectionId")),
            Date         = r.GetDateTime(r.GetOrdinal("Date")),
            SalonId      = r.GetInt32(r.GetOrdinal("SalonId")),
            SalonName    = r.GetString(r.GetOrdinal("SalonName")),
            StaffId      = r.IsDBNull(ordStaff)     ? null : r.GetInt32(ordStaff),
            StaffName    = r.IsDBNull(ordStaffName)  ? null : r.GetString(ordStaffName),
            HeadId       = r.IsDBNull(ordHead)       ? null : r.GetInt32(ordHead),
            HeadName     = r.IsDBNull(ordHeadName)   ? null : r.GetString(ordHeadName),
            Mode         = r.IsDBNull(ordMode)       ? null : r.GetString(ordMode),
            Amount       = r.IsDBNull(ordAmount)     ? null : r.GetDecimal(ordAmount),
            Description  = r.IsDBNull(ordDesc)       ? null : r.GetString(ordDesc),
            Status       = r.IsDBNull(ordStatus)     ? null : r.GetString(ordStatus),
            CreatedAt    = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt    = r.IsDBNull(ordUpdatedAt)  ? null : r.GetDateTime(ordUpdatedAt),
        };
    }

    private static SDExpence MapExpence(SqlDataReader r)
    {
        int ordHead      = r.GetOrdinal("HeadId");
        int ordHeadName  = r.GetOrdinal("HeadName");
        int ordExpType   = r.GetOrdinal("ExpenceType");
        int ordMode      = r.GetOrdinal("Mode");
        int ordAmount    = r.GetOrdinal("Amount");
        int ordDesc      = r.GetOrdinal("Description");
        int ordStatus    = r.GetOrdinal("Status");
        int ordUpdatedAt = r.GetOrdinal("UpdatedAt");
        return new SDExpence
        {
            ExpenceId     = r.GetInt32(r.GetOrdinal("ExpenceId")),
            Date          = r.GetDateTime(r.GetOrdinal("Date")),
            SalonId       = r.GetInt32(r.GetOrdinal("SalonId")),
            SalonName     = r.IsDBNull(r.GetOrdinal("SalonName")) ? null : r.GetString(r.GetOrdinal("SalonName")),
            HeadId        = r.IsDBNull(ordHead)      ? null : r.GetInt32(ordHead),
            HeadName      = r.IsDBNull(ordHeadName)  ? null : r.GetString(ordHeadName),
            ExpenceType   = r.IsDBNull(ordExpType)   ? null : r.GetString(ordExpType),
            Mode          = r.IsDBNull(ordMode)      ? null : r.GetString(ordMode),
            Amount        = r.IsDBNull(ordAmount)    ? null : r.GetDecimal(ordAmount),
            Description   = r.IsDBNull(ordDesc)      ? null : r.GetString(ordDesc),
            Status        = r.IsDBNull(ordStatus)    ? null : r.GetString(ordStatus),
            CreatedAt     = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt     = r.IsDBNull(ordUpdatedAt) ? null : r.GetDateTime(ordUpdatedAt),
        };
    }
}
