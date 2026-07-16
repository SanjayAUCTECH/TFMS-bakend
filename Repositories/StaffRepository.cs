using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class StaffRepository : IStaffRepository
{
    private readonly IDbConnectionFactory _factory;
    public StaffRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Staff> Data, int TotalRecords)> GetAllAsync(StaffListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",    request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Staff>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapStaff(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Staff?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetStaffById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapStaff(r) : null;
    }

    public async Task<Staff?> GetByUsernameAsync(string username)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM Staff WHERE Username=@Username", conn);
        cmd.Parameters.AddWithValue("@Username", username);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapStaff(r) : null;
    }

    public async Task<int> CreateAsync(Staff staff)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateStaff", conn) { CommandType = CommandType.StoredProcedure };
        AddCommonParams(cmd, staff);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Staff staff)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", staff.Id);
        AddCommonParams(cmd, staff);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteStaff", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                                          AS total,
                SUM(CASE WHEN Status='Active'        THEN 1 ELSE 0 END)          AS active,
                SUM(CASE WHEN Status='Inactive'      THEN 1 ELSE 0 END)          AS inactive,
                SUM(CASE WHEN LoginAccess='enabled'  THEN 1 ELSE 0 END)          AS withAccess
            FROM Staff", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { total=0, active=0, inactive=0, withAccess=0 };
        return new {
            total      = r.IsDBNull(0) ? 0 : r.GetInt32(0),
            active     = r.IsDBNull(1) ? 0 : r.GetInt32(1),
            inactive   = r.IsDBNull(2) ? 0 : r.GetInt32(2),
            withAccess = r.IsDBNull(3) ? 0 : r.GetInt32(3),
        };
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Staff WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    public async Task<bool> UsernameExistsAsync(string username, int? excludeId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        var sql = excludeId.HasValue
            ? "SELECT COUNT(1) FROM Staff WHERE Username=@Username AND Id<>@ExcludeId"
            : "SELECT COUNT(1) FROM Staff WHERE Username=@Username";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Username", username);
        if (excludeId.HasValue) cmd.Parameters.AddWithValue("@ExcludeId", excludeId.Value);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    // ── Shared parameter builder ──────────────────────────────────────────────

    private static void AddCommonParams(SqlCommand cmd, Staff s)
    {
        cmd.Parameters.AddWithValue("@Name",        s.Name);
        cmd.Parameters.AddWithValue("@Designation", s.Designation ?? "");
        cmd.Parameters.AddWithValue("@Contact",     s.Contact);
        cmd.Parameters.AddWithValue("@Email",       s.Email);
        cmd.Parameters.AddWithValue("@Address",     s.Address);
        cmd.Parameters.AddWithValue("@Username",    string.IsNullOrWhiteSpace(s.Username) ? (object)DBNull.Value : s.Username);
        cmd.Parameters.AddWithValue("@Password",    (object?)s.Password ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@LoginAccess", s.LoginAccess);
        cmd.Parameters.AddWithValue("@Status",      s.Status);
        cmd.Parameters.AddWithValue("@Remarks",     s.Remarks);
        cmd.Parameters.AddWithValue("@EmiratesId",  s.EmiratesId);
        cmd.Parameters.AddWithValue("@PassportNo",  s.PassportNo);
        cmd.Parameters.AddWithValue("@Nationality", s.Nationality);
        cmd.Parameters.AddWithValue("@JobTitle",    s.JobTitle);
        cmd.Parameters.AddWithValue("@MoveInDate",  (object?)s.MoveInDate  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@VisaExpiry",  (object?)s.VisaExpiry  ?? DBNull.Value);

        // Document dates
        cmd.Parameters.AddWithValue("@EmiratesIdIssueDate",  (object?)s.EmiratesIdIssueDate  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@EmiratesIdExpiryDate", (object?)s.EmiratesIdExpiryDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PassportIssueDate",    (object?)s.PassportIssueDate    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PassportExpiryDate",   (object?)s.PassportExpiryDate   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@LabourCardIssueDate",  (object?)s.LabourCardIssueDate  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@LabourCardExpiryDate", (object?)s.LabourCardExpiryDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@IloeIssueDate",        (object?)s.IloeIssueDate        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@IloeExpiryDate",       (object?)s.IloeExpiryDate       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@InsuranceIssueDate",   (object?)s.InsuranceIssueDate   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@InsuranceExpiryDate",  (object?)s.InsuranceExpiryDate  ?? DBNull.Value);

        // Document URLs
        cmd.Parameters.AddWithValue("@EmiratesIdDocument", string.IsNullOrEmpty(s.EmiratesIdDocument) ? (object)DBNull.Value : s.EmiratesIdDocument);
        cmd.Parameters.AddWithValue("@PassportDocument",   string.IsNullOrEmpty(s.PassportDocument)   ? (object)DBNull.Value : s.PassportDocument);
        cmd.Parameters.AddWithValue("@LabourCardDocument", string.IsNullOrEmpty(s.LabourCardDocument) ? (object)DBNull.Value : s.LabourCardDocument);
        cmd.Parameters.AddWithValue("@IloeDocument",       string.IsNullOrEmpty(s.IloeDocument)       ? (object)DBNull.Value : s.IloeDocument);
        cmd.Parameters.AddWithValue("@InsuranceDocument",  string.IsNullOrEmpty(s.InsuranceDocument)  ? (object)DBNull.Value : s.InsuranceDocument);
    }

    // ── Mapper ────────────────────────────────────────────────────────────────

    private static Staff MapStaff(SqlDataReader r) => new()
    {
        Id          = r.GetInt32(r.GetOrdinal("Id")),
        StaffId     = r.GetString(r.GetOrdinal("StaffId")),
        Name        = r.GetString(r.GetOrdinal("Name")),
        Role        = SafeStr(r, "Role", "Staff"),
        Designation = SafeStr(r, "Designation"),
        Contact     = SafeStr(r, "Contact"),
        Email       = SafeStr(r, "Email"),
        Address     = SafeStr(r, "Address"),
        Username    = SafeStr(r, "Username"),
        Password    = SafeStr(r, "Password"),
        LoginAccess = SafeStr(r, "LoginAccess", "enabled"),
        Status      = r.GetString(r.GetOrdinal("Status")),
        Remarks     = SafeStr(r, "Remarks"),
        EmiratesId  = SafeStr(r, "EmiratesId"),
        PassportNo  = SafeStr(r, "PassportNo"),
        Nationality = SafeStr(r, "Nationality"),
        JobTitle    = SafeStr(r, "JobTitle"),
        MoveInDate  = SafeDate(r, "MoveInDate"),
        VisaExpiry  = SafeDate(r, "VisaExpiry"),

        EmiratesIdIssueDate  = SafeDate(r, "EmiratesIdIssueDate"),
        EmiratesIdExpiryDate = SafeDate(r, "EmiratesIdExpiryDate"),
        PassportIssueDate    = SafeDate(r, "PassportIssueDate"),
        PassportExpiryDate   = SafeDate(r, "PassportExpiryDate"),
        LabourCardIssueDate  = SafeDate(r, "LabourCardIssueDate"),
        LabourCardExpiryDate = SafeDate(r, "LabourCardExpiryDate"),
        IloeIssueDate        = SafeDate(r, "IloeIssueDate"),
        IloeExpiryDate       = SafeDate(r, "IloeExpiryDate"),
        InsuranceIssueDate   = SafeDate(r, "InsuranceIssueDate"),
        InsuranceExpiryDate  = SafeDate(r, "InsuranceExpiryDate"),

        EmiratesIdDocument = SafeStr(r, "EmiratesIdDocument"),
        PassportDocument   = SafeStr(r, "PassportDocument"),
        LabourCardDocument = SafeStr(r, "LabourCardDocument"),
        IloeDocument       = SafeStr(r, "IloeDocument"),
        InsuranceDocument  = SafeStr(r, "InsuranceDocument"),

        CreatedAt   = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt   = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static string SafeStr(SqlDataReader r, string col, string def = "")
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? def : r.GetString(o); } catch { return def; }
    }

    private static DateTime? SafeDate(SqlDataReader r, string col)
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? null : r.GetDateTime(o); } catch { return null; }
    }
}
