using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class CampRepository : ICampRepository
{
    private readonly IDbConnectionFactory _factory;
    public CampRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Camp> Data, int TotalRecords)> GetAllAsync(CampListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCamps", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status    ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var dict = new Dictionary<int, Camp>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var cId = r.GetInt32(r.GetOrdinal("Id"));
            if (!dict.ContainsKey(cId))
                dict[cId] = MapCamp(r);

            // Partners
            if (!r.IsDBNull(r.GetOrdinal("CampPartnerId")))
            {
                var cp = new CampPartner
                {
                    Id          = r.GetInt32(r.GetOrdinal("CampPartnerId")),
                    CampId      = cId,
                    PartnerId   = r.GetInt32(r.GetOrdinal("PartnerId")),
                    PartnerName = r.IsDBNull(r.GetOrdinal("PartnerName")) ? "" : r.GetString(r.GetOrdinal("PartnerName")),
                    ShareType   = r.GetString(r.GetOrdinal("PartnerShareType")),
                    ShareValue  = r.GetDecimal(r.GetOrdinal("PartnerShareValue")),
                };
                if (!dict[cId].Partners.Any(p => p.Id == cp.Id))
                    dict[cId].Partners.Add(cp);
            }

            // Owners
            if (!r.IsDBNull(r.GetOrdinal("CampOwnerId")))
            {
                var co = new CampOwner
                {
                    Id        = r.GetInt32(r.GetOrdinal("CampOwnerId")),
                    CampId    = cId,
                    OwnerId   = r.GetInt32(r.GetOrdinal("OwnerId")),
                    OwnerName = r.IsDBNull(r.GetOrdinal("OwnerName")) ? "" : r.GetString(r.GetOrdinal("OwnerName")),
                    ShareType = r.GetString(r.GetOrdinal("OwnerShareType")),
                    ShareValue = r.GetDecimal(r.GetOrdinal("OwnerShareValue")),
                };
                if (!dict[cId].Owners.Any(o => o.Id == co.Id))
                    dict[cId].Owners.Add(co);
            }
        }
        await r.CloseAsync();
        return (dict.Values, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<IEnumerable<Camp>> GetAllActiveAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT Id,Code,Name,Rooms,Floors,Status,CreatedAt,UpdatedAt FROM Camps WHERE Status='Active' ORDER BY Name", conn);
        var list = new List<Camp>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapCamp(r));
        return list;
    }

    public async Task<Camp?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        Camp? camp = null;
        while (await r.ReadAsync())
        {
            camp ??= MapCamp(r);
            if (!r.IsDBNull(r.GetOrdinal("PartnerId")))
            {
                camp.Partners.Add(new CampPartner
                {
                    Id          = r.GetInt32(r.GetOrdinal("CampPartnerId")),
                    CampId      = id,
                    PartnerId   = r.GetInt32(r.GetOrdinal("PartnerId")),
                    PartnerName = r.IsDBNull(r.GetOrdinal("PartnerName")) ? "" : r.GetString(r.GetOrdinal("PartnerName")),
                    ShareType   = r.GetString(r.GetOrdinal("PartnerShareType")),
                    ShareValue  = r.GetDecimal(r.GetOrdinal("PartnerShareValue")),
                });
            }
            if (!r.IsDBNull(r.GetOrdinal("OwnerId")))
            {
                camp.Owners.Add(new CampOwner
                {
                    Id        = r.GetInt32(r.GetOrdinal("CampOwnerId")),
                    CampId    = id,
                    OwnerId   = r.GetInt32(r.GetOrdinal("OwnerId")),
                    OwnerName = r.IsDBNull(r.GetOrdinal("OwnerName")) ? "" : r.GetString(r.GetOrdinal("OwnerName")),
                    ShareType = r.GetString(r.GetOrdinal("OwnerShareType")),
                    ShareValue = r.GetDecimal(r.GetOrdinal("OwnerShareValue")),
                });
            }
        }
        return camp;
    }

    public async Task<int> CreateAsync(Camp camp)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateCamp", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Name",               camp.Name);
        cmd.Parameters.AddWithValue("@Status",             camp.Status);
        cmd.Parameters.AddWithValue("@StartDate",          (object?)camp.StartDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@EndDate",            (object?)camp.EndDate   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampPropertyUsage",  camp.CampPropertyUsage);
        cmd.Parameters.AddWithValue("@CampBuildingName",   camp.CampBuildingName);
        cmd.Parameters.AddWithValue("@CampPropertyType",   camp.CampPropertyType);
        cmd.Parameters.AddWithValue("@CampLocation",       camp.CampLocation);
        cmd.Parameters.AddWithValue("@CampPropertyNo",     camp.CampPropertyNo);
        cmd.Parameters.AddWithValue("@CampPropertyArea",   camp.CampPropertyArea);
        cmd.Parameters.AddWithValue("@CampPremisesNo",     camp.CampPremisesNo);
        cmd.Parameters.AddWithValue("@CampPlotNo",         camp.CampPlotNo);
        cmd.Parameters.AddWithValue("@CampMakaniNo",       camp.CampMakaniNo);
        var partnersJson = System.Text.Json.JsonSerializer.Serialize(camp.Partners.Select(p => new { p.PartnerId, p.ShareType, p.ShareValue }));
        var ownersJson   = System.Text.Json.JsonSerializer.Serialize(camp.Owners.Select(o => new { o.OwnerId, o.ShareType, o.ShareValue }));
        cmd.Parameters.AddWithValue("@PartnersJson", partnersJson);
        cmd.Parameters.AddWithValue("@OwnersJson",   ownersJson);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Camp camp)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateCamp", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",                 camp.Id);
        cmd.Parameters.AddWithValue("@Name",               camp.Name);
        cmd.Parameters.AddWithValue("@Status",             camp.Status);
        cmd.Parameters.AddWithValue("@StartDate",          (object?)camp.StartDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@EndDate",            (object?)camp.EndDate   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampPropertyUsage",  camp.CampPropertyUsage);
        cmd.Parameters.AddWithValue("@CampBuildingName",   camp.CampBuildingName);
        cmd.Parameters.AddWithValue("@CampPropertyType",   camp.CampPropertyType);
        cmd.Parameters.AddWithValue("@CampLocation",       camp.CampLocation);
        cmd.Parameters.AddWithValue("@CampPropertyNo",     camp.CampPropertyNo);
        cmd.Parameters.AddWithValue("@CampPropertyArea",   camp.CampPropertyArea);
        cmd.Parameters.AddWithValue("@CampPremisesNo",     camp.CampPremisesNo);
        cmd.Parameters.AddWithValue("@CampPlotNo",         camp.CampPlotNo);
        cmd.Parameters.AddWithValue("@CampMakaniNo",       camp.CampMakaniNo);
        var partnersJson = System.Text.Json.JsonSerializer.Serialize(camp.Partners.Select(p => new { p.PartnerId, p.ShareType, p.ShareValue }));
        var ownersJson   = System.Text.Json.JsonSerializer.Serialize(camp.Owners.Select(o => new { o.OwnerId, o.ShareType, o.ShareValue }));
        cmd.Parameters.AddWithValue("@PartnersJson", partnersJson);
        cmd.Parameters.AddWithValue("@OwnersJson",   ownersJson);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                            AS total,
                SUM(CASE WHEN Status='Active'   THEN 1 ELSE 0 END) AS active,
                (SELECT COUNT(*) FROM Rooms)                        AS totalRooms,
                CASE WHEN COUNT(*)>0 THEN (SELECT COUNT(*) FROM Rooms)/COUNT(*) ELSE 0 END AS avgRooms
            FROM Camps", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { total=0, active=0, totalRooms=0, avgRooms=0 };
        return new {
            total      = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            active     = r.IsDBNull(1) ? 0 : r.GetInt32(1),
            totalRooms = r.IsDBNull(2) ? 0 : r.GetInt32(2),
            avgRooms   = r.IsDBNull(3) ? 0 : r.GetInt32(3),
        };
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteCamp", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    private static Camp MapCamp(SqlDataReader r) => new()
    {
        Id                = r.GetInt32(r.GetOrdinal("Id")),
        Code              = r.GetString(r.GetOrdinal("Code")),
        Name              = r.GetString(r.GetOrdinal("Name")),
        Rooms             = r.GetInt32(r.GetOrdinal("Rooms")),
        Floors            = r.GetInt32(r.GetOrdinal("Floors")),
        Status            = r.GetString(r.GetOrdinal("Status")),
        CampPropertyUsage = SafeStr(r, "CampPropertyUsage"),
        CampBuildingName  = SafeStr(r, "CampBuildingName"),
        CampPropertyType  = SafeStr(r, "CampPropertyType"),
        CampLocation      = SafeStr(r, "CampLocation"),
        CampPropertyNo    = SafeStr(r, "CampPropertyNo"),
        CampPropertyArea  = SafeStr(r, "CampPropertyArea"),
        CampPremisesNo    = SafeStr(r, "CampPremisesNo"),
        CampPlotNo        = SafeStr(r, "CampPlotNo"),
        CampMakaniNo      = SafeStr(r, "CampMakaniNo"),
        StartDate         = SafeDate(r, "StartDate"),
        EndDate           = SafeDate(r, "EndDate"),
        CreatedAt         = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt         = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static string SafeStr(SqlDataReader r, string col)
    {
        try { var ord = r.GetOrdinal(col); return r.IsDBNull(ord) ? "" : r.GetString(ord); }
        catch { return ""; }
    }

    private static DateTime? SafeDate(SqlDataReader r, string col)
    {
        try { var ord = r.GetOrdinal(col); return r.IsDBNull(ord) ? null : r.GetDateTime(ord); }
        catch { return null; }
    }
}
