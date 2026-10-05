using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class AccountMasterRepository : IAccountMasterRepository
{
    private readonly IDbConnectionFactory _factory;
    public AccountMasterRepository(IDbConnectionFactory factory) => _factory = factory;

    // ──────────────────────────────────────────────────────────────
    // GET ALL  →  sp_GetAccountMasters
    // ──────────────────────────────────────────────────────────────
    public async Task<(IEnumerable<AccountMaster> Data, int TotalRecords)> GetAllAsync(AccountMasterListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetAccountMasters", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        // Pagination
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);

        // Filters
        cmd.Parameters.AddWithValue("@PaymentType", string.IsNullOrEmpty(request.PaymentType) ? (object)DBNull.Value : request.PaymentType);
        cmd.Parameters.AddWithValue("@Nature", string.IsNullOrEmpty(request.Nature) ? (object)DBNull.Value : request.Nature);
        cmd.Parameters.AddWithValue("@RecipientId", request.RecipientId.HasValue ? (object)request.RecipientId.Value : DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPool", string.IsNullOrEmpty(request.FundPool) ? (object)DBNull.Value : request.FundPool);
        cmd.Parameters.AddWithValue("@Mode", string.IsNullOrEmpty(request.Mode) ? (object)DBNull.Value : request.Mode);
        cmd.Parameters.AddWithValue("@CampId", request.CampId.HasValue ? (object)request.CampId.Value : DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHead", string.IsNullOrEmpty(request.AccountHead) ? (object)DBNull.Value : request.AccountHead);

        // Date filters
        cmd.Parameters.AddWithValue("@DateFrom",
            !string.IsNullOrEmpty(request.DateFrom) && DateTime.TryParse(request.DateFrom, out var df)
                ? (object)df.Date : DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",
            !string.IsNullOrEmpty(request.DateTo) && DateTime.TryParse(request.DateTo, out var dt)
                ? (object)dt.Date : DBNull.Value);

        // PaymentDate filters
        cmd.Parameters.AddWithValue("@PaymentDate",
            !string.IsNullOrEmpty(request.PaymentDate) && DateTime.TryParse(request.PaymentDate, out var pd)
                ? (object)pd.Date : DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentDateFrom",
            !string.IsNullOrEmpty(request.PaymentDateFrom) && DateTime.TryParse(request.PaymentDateFrom, out var pdf)
                ? (object)pdf.Date : DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentDateTo",
            !string.IsNullOrEmpty(request.PaymentDateTo) && DateTime.TryParse(request.PaymentDateTo, out var pdt)
                ? (object)pdt.Date : DBNull.Value);

        // Search text
        cmd.Parameters.AddWithValue("@SearchText",
            string.IsNullOrEmpty(request.SearchText) ? (object)DBNull.Value : "%" + request.SearchText + "%");

        // Output parameter for total count
        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        // Execute and read data
        var list = new List<AccountMaster>();
        await using (var r = await cmd.ExecuteReaderAsync())
        {
            while (await r.ReadAsync()) list.Add(Map(r));
        }

        // Now read output parameter (after reader is closed)
        var total = (int)(totalParam.Value ?? 0);
        return (list, total);
    }

    // ──────────────────────────────────────────────────────────────
    // GET BY ID
    // ──────────────────────────────────────────────────────────────
    public async Task<AccountMaster?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "SELECT * FROM AccountMasters WHERE Id=@Id AND IsDeleted=0", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    // ──────────────────────────────────────────────────────────────
    // CREATE  →  sp_CreateAccountMaster
    // ──────────────────────────────────────────────────────────────
    public async Task<int> CreateAsync(AccountMaster master, List<AccountMasterHeadItem> heads,
        int? userId, string? requestedVoucherNo = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_CreateAccountMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        // ── Scalar params ──
        cmd.Parameters.AddWithValue("@TransDate",     master.TransDate);
        cmd.Parameters.AddWithValue("@PaymentDate",   (object?)master.PaymentDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode",          master.Mode          ?? "");
        cmd.Parameters.AddWithValue("@VoucherNo",     string.IsNullOrWhiteSpace(requestedVoucherNo)
                                                        ? (object)DBNull.Value
                                                        : requestedVoucherNo.Trim());
        cmd.Parameters.AddWithValue("@FundPool",      master.FundPool      ?? "");
        cmd.Parameters.AddWithValue("@FundPoolName",  master.FundPoolName  ?? "");
        cmd.Parameters.AddWithValue("@Nature",        master.Nature        ?? "");
        cmd.Parameters.AddWithValue("@CampId",        (object?)master.CampId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampName",      master.CampName      ?? "");
        cmd.Parameters.AddWithValue("@RecipientRole", master.RecipientRole ?? "");
        cmd.Parameters.AddWithValue("@RecipientId",   (object?)master.RecipientId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientName", master.RecipientName ?? "");
        cmd.Parameters.AddWithValue("@Purpose",       master.Purpose       ?? "");
        cmd.Parameters.AddWithValue("@AddedBy",       (object?)userId      ?? DBNull.Value);

        // ── Table-valued param (Heads) ──
        var tvp = BuildHeadsTvp(heads);
        var tvpParam = cmd.Parameters.AddWithValue("@Heads", tvp);
        tvpParam.SqlDbType = SqlDbType.Structured;
        tvpParam.TypeName  = "dbo.AccountMasterHeadType";

        // ── OUTPUT param ──
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);

        try
        {
            await cmd.ExecuteNonQueryAsync();
        }
        catch (SqlException ex) when (ex.Message.Contains("VOUCHER_EXISTS"))
        {
            throw new InvalidOperationException("VOUCHER_EXISTS");
        }

        return (int)newId.Value;
    }

    // ──────────────────────────────────────────────────────────────
    // UPDATE  →  sp_UpdateAccountMaster
    // ──────────────────────────────────────────────────────────────
    public async Task<bool> UpdateAsync(int id, AccountMaster master,
        List<AccountMasterHeadItem> heads, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateAccountMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id",            id);
        cmd.Parameters.AddWithValue("@TransDate",     master.TransDate);
        cmd.Parameters.AddWithValue("@PaymentDate",   (object?)master.PaymentDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Mode",          master.Mode          ?? "");
        cmd.Parameters.AddWithValue("@FundPool",      master.FundPool      ?? "");
        cmd.Parameters.AddWithValue("@FundPoolName",  master.FundPoolName  ?? "");
        cmd.Parameters.AddWithValue("@Nature",        master.Nature        ?? "");
        cmd.Parameters.AddWithValue("@CampId",        (object?)master.CampId       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampName",      master.CampName      ?? "");
        cmd.Parameters.AddWithValue("@RecipientRole", master.RecipientRole ?? "");
        cmd.Parameters.AddWithValue("@RecipientId",   (object?)master.RecipientId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientName", master.RecipientName ?? "");
        cmd.Parameters.AddWithValue("@Purpose",       master.Purpose       ?? "");
        cmd.Parameters.AddWithValue("@UpdatedBy",     (object?)userId      ?? DBNull.Value);

        // ── Table-valued param (Heads) ──
        var tvp = BuildHeadsTvp(heads);
        var tvpParam = cmd.Parameters.AddWithValue("@Heads", tvp);
        tvpParam.SqlDbType = SqlDbType.Structured;
        tvpParam.TypeName  = "dbo.AccountMasterHeadType";

        try
        {
            await cmd.ExecuteNonQueryAsync();
            return true;
        }
        catch (SqlException ex) when (ex.Message.Contains("RECORD_NOT_FOUND"))
        {
            return false;
        }
    }

    // ──────────────────────────────────────────────────────────────
    // DELETE  →  sp_DeleteAccountMaster
    // ──────────────────────────────────────────────────────────────
    public async Task<bool> DeleteAsync(int id, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeleteAccountMaster", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)userId ?? DBNull.Value);

        try
        {
            await cmd.ExecuteNonQueryAsync();
            return true;
        }
        catch (SqlException ex) when (ex.Message.Contains("RECORD_NOT_FOUND"))
        {
            return false;
        }
    }

    // ──────────────────────────────────────────────────────────────
    // GET HEADS BY ACCOUNT ID  (used in service for response)
    // ──────────────────────────────────────────────────────────────
    public async Task<List<(int Id, string PaymentType, string Head, decimal Amount,
        string Purpose, string RefId, int? CampId, string CampName)>>
        GetHeadsByAccountIdAsync(string accountId)
    {
        var result = new List<(int, string, string, decimal, string, string, int?, string)>();
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Income heads
        await using (var cmd = new SqlCommand(
            "SELECT Id, Head, Amount, Purpose, IncomeId, CampId, ISNULL(CampName,'') FROM Incomes WHERE AccountId=@AccId AND IsDeleted=0", conn))
        {
            cmd.Parameters.AddWithValue("@AccId", accountId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                result.Add((
                    r.GetInt32(0), "Income",
                    r.IsDBNull(1) ? "" : r.GetString(1),
                    r.GetDecimal(2),
                    r.IsDBNull(3) ? "" : r.GetString(3),
                    r.IsDBNull(4) ? "" : r.GetString(4),
                    r.IsDBNull(5) ? null : r.GetInt32(5),
                    r.GetString(6)));
        }

        // Expense heads
        await using (var cmd = new SqlCommand(
            "SELECT Id, Head, Amount, Purpose, ExpenseId, CampId, ISNULL(CampName,'') FROM Expenses WHERE AccountId=@AccId AND IsDeleted=0", conn))
        {
            cmd.Parameters.AddWithValue("@AccId", accountId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                result.Add((
                    r.GetInt32(0), "Expense",
                    r.IsDBNull(1) ? "" : r.GetString(1),
                    r.GetDecimal(2),
                    r.IsDBNull(3) ? "" : r.GetString(3),
                    r.IsDBNull(4) ? "" : r.GetString(4),
                    r.IsDBNull(5) ? null : r.GetInt32(5),
                    r.GetString(6)));
        }

        return result;
    }

    // ──────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ──────────────────────────────────────────────────────────────

    /// <summary>Build in-memory DataTable to pass as TVP @Heads</summary>
    private static DataTable BuildHeadsTvp(List<AccountMasterHeadItem> heads)
    {
        var dt = new DataTable();
        dt.Columns.Add("PaymentType", typeof(string));
        dt.Columns.Add("Head",        typeof(string));
        dt.Columns.Add("Amount",      typeof(decimal));
        dt.Columns.Add("Purpose",     typeof(string));

        foreach (var h in heads)
            dt.Rows.Add(h.PaymentType, h.Head, h.Amount, h.Purpose ?? "");

        return dt;
    }

    private static AccountMaster Map(SqlDataReader r) => new()
    {
        Id            = r.GetInt32(r.GetOrdinal("Id")),
        AccountId     = r.IsDBNull(r.GetOrdinal("AccountId"))     ? "" : r.GetString(r.GetOrdinal("AccountId")),
        VoucherNo     = r.IsDBNull(r.GetOrdinal("VoucherNo"))     ? "" : r.GetString(r.GetOrdinal("VoucherNo")),
        TransDate     = r.GetDateTime(r.GetOrdinal("TransDate")),
        PaymentDate   = r.IsDBNull(r.GetOrdinal("PaymentDate"))   ? null : r.GetDateTime(r.GetOrdinal("PaymentDate")),
        PaymentType   = r.IsDBNull(r.GetOrdinal("PaymentType"))   ? "" : r.GetString(r.GetOrdinal("PaymentType")),
        Mode          = r.IsDBNull(r.GetOrdinal("Mode"))          ? "" : r.GetString(r.GetOrdinal("Mode")),
        FundPool      = r.IsDBNull(r.GetOrdinal("FundPool"))      ? "" : r.GetString(r.GetOrdinal("FundPool")),
        FundPoolName  = r.IsDBNull(r.GetOrdinal("FundPoolName"))  ? "" : r.GetString(r.GetOrdinal("FundPoolName")),
        Amount        = r.GetDecimal(r.GetOrdinal("Amount")),
        Nature        = r.IsDBNull(r.GetOrdinal("Nature"))        ? "" : r.GetString(r.GetOrdinal("Nature")),
        RecipientRole = r.IsDBNull(r.GetOrdinal("RecipientRole")) ? "" : r.GetString(r.GetOrdinal("RecipientRole")),
        RecipientName = r.IsDBNull(r.GetOrdinal("RecipientName")) ? "" : r.GetString(r.GetOrdinal("RecipientName")),
        Purpose       = r.IsDBNull(r.GetOrdinal("Purpose"))       ? "" : r.GetString(r.GetOrdinal("Purpose")),
        RecipientId   = r.IsDBNull(r.GetOrdinal("RecipientId"))   ? null : r.GetInt32(r.GetOrdinal("RecipientId")),
        CreatedAt     = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt     = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
