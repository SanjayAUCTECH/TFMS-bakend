using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class TenantRepository : ITenantRepository
{
    private readonly IDbConnectionFactory _factory;
    public TenantRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Tenant> Data, int TotalRecords)> GetAllAsync(TenantListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTenants", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status    ?? DBNull.Value);
        // @Type not in sp_GetTenants — skip it
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Id",            (object?)request.Id        ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Tenant>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Tenant?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTenantById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(Tenant t)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateTenant", conn) { CommandType = CommandType.StoredProcedure };
        AddParams(cmd, t);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Tenant t)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateTenant", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", t.Id);
        AddParams(cmd, t);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteTenant", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                                      AS total,
                SUM(CASE WHEN Status='Active'   THEN 1 ELSE 0 END)           AS active,
                SUM(CASE WHEN Status='Inactive' THEN 1 ELSE 0 END)           AS inactive,
                SUM(CASE WHEN Type='Company'    THEN 1 ELSE 0 END)           AS companies
            FROM Tenants", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { total=0, active=0, inactive=0, companies=0 };
        return new {
            total     = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            active    = r.IsDBNull(1) ? 0 : r.GetInt32(1),
            inactive  = r.IsDBNull(2) ? 0 : r.GetInt32(2),
            companies = r.IsDBNull(3) ? 0 : r.GetInt32(3),
        };
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Tenants WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static void AddParams(SqlCommand cmd, Tenant t)
    {
        cmd.Parameters.AddWithValue("@Type",                t.Type);
        cmd.Parameters.AddWithValue("@Name",                t.Name);
        cmd.Parameters.AddWithValue("@Passport",            t.Passport);
        cmd.Parameters.AddWithValue("@Nationality",         t.Nationality);
        cmd.Parameters.AddWithValue("@EmiratesId",          t.EmiratesId);
        cmd.Parameters.AddWithValue("@Contact",             t.Contact);
        cmd.Parameters.AddWithValue("@Whatsapp",            t.Whatsapp);
        cmd.Parameters.AddWithValue("@Email",               t.Email);
        cmd.Parameters.AddWithValue("@Address",             t.Address);
        cmd.Parameters.AddWithValue("@Status",              t.Status);
        cmd.Parameters.AddWithValue("@Company",             t.Company);
        cmd.Parameters.AddWithValue("@TradeLicense",        t.TradeLicense);
        cmd.Parameters.AddWithValue("@LicensingAuthority",  t.LicensingAuthority);
        cmd.Parameters.AddWithValue("@NumberOfCoOccupants", t.NumberOfCoOccupants);
        cmd.Parameters.AddWithValue("@PlotNo",              t.PlotNo);
        cmd.Parameters.AddWithValue("@MakaniNo",            t.MakaniNo);
        cmd.Parameters.AddWithValue("@PropertyArea",        t.PropertyArea);
        cmd.Parameters.AddWithValue("@PremisesNo",          t.PremisesNo);
        cmd.Parameters.AddWithValue("@LessorName",          t.LessorName);
        cmd.Parameters.AddWithValue("@LessorEid",           t.LessorEid);
        cmd.Parameters.AddWithValue("@LessorLicense",       t.LessorLicense);
        cmd.Parameters.AddWithValue("@LessorLicAuthority",  t.LessorLicAuthority);
        cmd.Parameters.AddWithValue("@LessorEmail",         t.LessorEmail);
        cmd.Parameters.AddWithValue("@LessorPhone",         t.LessorPhone);
    }

    private static Tenant Map(SqlDataReader r)
    {
        string G(string col) => r.IsDBNull(r.GetOrdinal(col)) ? "" : r.GetString(r.GetOrdinal(col));
        return new Tenant
        {
            Id                  = r.GetInt32(r.GetOrdinal("Id")),
            Type                = G("Type"),
            Name                = G("Name"),
            Passport            = G("Passport"),
            Nationality         = G("Nationality"),
            EmiratesId          = G("EmiratesId"),
            Contact             = G("Contact"),
            Whatsapp            = G("Whatsapp"),
            Email               = G("Email"),
            Address             = G("Address"),
            Status              = G("Status"),
            Company             = G("Company"),
            TradeLicense        = G("TradeLicense"),
            LicensingAuthority  = G("LicensingAuthority"),
            NumberOfCoOccupants = G("NumberOfCoOccupants"),
            PlotNo              = G("PlotNo"),
            MakaniNo            = G("MakaniNo"),
            PropertyArea        = G("PropertyArea"),
            PremisesNo          = G("PremisesNo"),
            LessorName          = G("LessorName"),
            LessorEid           = G("LessorEid"),
            LessorLicense       = G("LessorLicense"),
            LessorLicAuthority  = G("LessorLicAuthority"),
            LessorEmail         = G("LessorEmail"),
            LessorPhone         = G("LessorPhone"),
            CreatedAt           = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            UpdatedAt           = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
        };
    }
}
