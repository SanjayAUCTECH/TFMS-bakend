using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class AccountMasterRepository : IAccountMasterRepository
{
    private readonly IDbConnectionFactory _factory;
    public AccountMasterRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<AccountMaster> Data, int TotalRecords)> GetAllAsync(AccountMasterListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var where = "WHERE IsDeleted=0";
        if (!string.IsNullOrEmpty(request.PaymentType)) where += " AND PaymentType=@PaymentType";
        if (!string.IsNullOrEmpty(request.Nature)) where += " AND Nature=@Nature";
        if (request.RecipientId.HasValue) where += " AND RecipientId=@RecipientId";
        if (!string.IsNullOrEmpty(request.DateFrom)) where += " AND CAST(TransDate AS DATE)>=@DateFrom";
        if (!string.IsNullOrEmpty(request.DateTo))   where += " AND CAST(TransDate AS DATE)<=@DateTo";
        if (!string.IsNullOrEmpty(request.SearchText))
            where += " AND (AccountId LIKE @Search OR VoucherNo LIKE @Search OR Purpose LIKE @Search OR RecipientName LIKE @Search OR Mode LIKE @Search OR RecipientRole LIKE @Search)";

        // Count
        await using var countCmd = new SqlCommand($"SELECT COUNT(*) FROM AccountMasters {where}", conn);
        AddFilterParams(countCmd, request);
        var total = (int)(await countCmd.ExecuteScalarAsync())!;

        // Data
        var sql = $@"SELECT * FROM AccountMasters {where}
            ORDER BY TransDate DESC, Id DESC
            OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";
        await using var cmd = new SqlCommand(sql, conn);
        AddFilterParams(cmd, request);
        cmd.Parameters.AddWithValue("@Offset", (request.ResolvedPageNumber - 1) * request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);

        var list = new List<AccountMaster>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return (list, total);
    }

    public async Task<AccountMaster?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM AccountMasters WHERE Id=@Id AND IsDeleted=0", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(AccountMaster master, List<AccountMasterHeadItem> heads, int? userId, string? requestedVoucherNo = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var txn = (SqlTransaction)await conn.BeginTransactionAsync();

        try
        {
            // Generate AccountId
            var accSeq = 0;
            await using (var seqCmd = new SqlCommand("SELECT ISNULL(MAX(Id),0)+1 FROM AccountMasters", conn, txn))
            { accSeq = (int)(await seqCmd.ExecuteScalarAsync())!; }
            var accountId = "ACC-" + accSeq.ToString("D6");

            // VoucherNo: if provided check uniqueness, else auto-generate
            string voucherNo;
            if (!string.IsNullOrWhiteSpace(requestedVoucherNo))
            {
                // Check if already exists
                await using var chkCmd = new SqlCommand("SELECT COUNT(1) FROM AccountMasters WHERE VoucherNo=@Vch AND IsDeleted=0", conn, txn);
                chkCmd.Parameters.AddWithValue("@Vch", requestedVoucherNo.Trim());
                var exists = (int)(await chkCmd.ExecuteScalarAsync())! > 0;
                if (exists) throw new InvalidOperationException("VOUCHER_EXISTS");
                voucherNo = requestedVoucherNo.Trim();
            }
            else
            {
                voucherNo = "VCH-" + accSeq.ToString("D6");
            }

            // Total amount = sum of all heads
            var totalAmount = heads.Sum(h => h.Amount);

            // Get FundPool code
            string fundPoolCode = "";
            if (master.FundPool != null && master.FundPool.Length > 0)
                fundPoolCode = master.FundPool;

            // Resolve FundPool from Id if Code empty
            if (string.IsNullOrEmpty(fundPoolCode) && master.FundPool == "" && master.Id == 0)
            {
                // FundPoolName might be set, but we need code from FundPools table
                // Will be resolved from service layer
            }

            // 1. INSERT AccountMasters (parent)
            await using (var insCmd = new SqlCommand(@"
                INSERT INTO AccountMasters(
                    AccountId, VoucherNo, TransDate, PaymentType,
                    Mode, FundPool, FundPoolName, Amount,
                    Nature, RecipientRole, RecipientName, Purpose,
                    RecipientId, AddedBy, IsDeleted, CreatedAt, UpdatedAt
                ) VALUES(
                    @AccountId, @VoucherNo, @TransDate, @PaymentType,
                    @Mode, @FundPool, @FundPoolName, @Amount,
                    @Nature, @RecipientRole, @RecipientName, @Purpose,
                    @RecipientId, @AddedBy, 0, GETDATE(), GETDATE()
                ); SELECT SCOPE_IDENTITY();", conn, txn))
            {
                // PaymentType = mixed (both Income & Expense heads possible)
                var paymentType = heads.All(h => h.PaymentType == "Income") ? "Income"
                    : heads.All(h => h.PaymentType == "Expense") ? "Expense" : "Mixed";

                insCmd.Parameters.AddWithValue("@AccountId", accountId);
                insCmd.Parameters.AddWithValue("@VoucherNo", voucherNo);
                insCmd.Parameters.AddWithValue("@TransDate", master.TransDate);
                insCmd.Parameters.AddWithValue("@PaymentType", paymentType);
                insCmd.Parameters.AddWithValue("@Mode", master.Mode ?? "");
                insCmd.Parameters.AddWithValue("@FundPool", fundPoolCode);
                insCmd.Parameters.AddWithValue("@FundPoolName", master.FundPoolName ?? "");
                insCmd.Parameters.AddWithValue("@Amount", totalAmount);
                insCmd.Parameters.AddWithValue("@Nature", master.Nature ?? "");
                insCmd.Parameters.AddWithValue("@RecipientRole", master.RecipientRole ?? "");
                insCmd.Parameters.AddWithValue("@RecipientName", master.RecipientName ?? "");
                insCmd.Parameters.AddWithValue("@Purpose", master.Purpose ?? "");
                insCmd.Parameters.AddWithValue("@RecipientId", (object?)master.RecipientId ?? DBNull.Value);
                insCmd.Parameters.AddWithValue("@AddedBy", (object?)userId ?? DBNull.Value);

                var newId = await insCmd.ExecuteScalarAsync();
                master.Id = Convert.ToInt32(newId);
            }

            // 2. INSERT each head into Incomes or Expenses
            foreach (var head in heads)
            {
                if (head.PaymentType == "Income")
                {
                    // Generate IncomeId
                    string incomeId = "";
                    await using (var idCmd = new SqlCommand("SELECT 'INC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS VARCHAR),6)", conn, txn))
                    { incomeId = (string)(await idCmd.ExecuteScalarAsync())!; }

                    await using var incCmd = new SqlCommand(@"
                        INSERT INTO Incomes(
                            IncomeId, [Date], Mode, Head, FundPool, FundPoolName,
                            Amount, Purpose, Source, SourceRef,
                            CampId, CampName, AccountId, VoucherNo, TransDate,
                            AddedBy, IsDeleted, CreatedAt, UpdatedAt
                        ) VALUES(
                            @IncomeId, @Date, @Mode, @Head, @FundPool, @FundPoolName,
                            @Amount, @Purpose, 'Manual', '',
                            @CampId, @CampName, @AccountId, @VoucherNo, @TransDate,
                            @AddedBy, 0, GETDATE(), GETDATE()
                        )", conn, txn);
                    incCmd.Parameters.AddWithValue("@IncomeId", incomeId);
                    incCmd.Parameters.AddWithValue("@Date", master.TransDate);
                    incCmd.Parameters.AddWithValue("@Mode", master.Mode ?? "");
                    incCmd.Parameters.AddWithValue("@Head", head.Head);
                    incCmd.Parameters.AddWithValue("@FundPool", fundPoolCode);
                    incCmd.Parameters.AddWithValue("@FundPoolName", master.FundPoolName ?? "");
                    incCmd.Parameters.AddWithValue("@Amount", head.Amount);
                    incCmd.Parameters.AddWithValue("@Purpose", head.Purpose ?? master.Purpose ?? "");
                    incCmd.Parameters.AddWithValue("@CampId", (object?)master.CampId ?? DBNull.Value);
                    incCmd.Parameters.AddWithValue("@CampName", master.CampName ?? "");
                    incCmd.Parameters.AddWithValue("@AccountId", accountId);
                    incCmd.Parameters.AddWithValue("@VoucherNo", voucherNo);
                    incCmd.Parameters.AddWithValue("@TransDate", master.TransDate);
                    incCmd.Parameters.AddWithValue("@AddedBy", (object?)userId ?? DBNull.Value);
                    await incCmd.ExecuteNonQueryAsync();
                }
                else if (head.PaymentType == "Expense")
                {
                    // Generate ExpenseId
                    string expenseId = "";
                    await using (var idCmd = new SqlCommand("SELECT 'EXP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS VARCHAR),6)", conn, txn))
                    { expenseId = (string)(await idCmd.ExecuteScalarAsync())!; }

                    await using var expCmd = new SqlCommand(@"
                        INSERT INTO Expenses(
                            ExpenseId, [Date], Mode, Head, FundPool, FundPoolName,
                            Amount, Nature, CampId, CampName,
                            RecipientRole, RecipientId, RecipientName,
                            Purpose, AccountId, VoucherNo, TransDate,
                            AddedBy, IsDeleted, CreatedAt, UpdatedAt
                        ) VALUES(
                            @ExpenseId, @Date, @Mode, @Head, @FundPool, @FundPoolName,
                            @Amount, @Nature, @CampId, @CampName,
                            @RecipientRole, @RecipientId, @RecipientName,
                            @Purpose, @AccountId, @VoucherNo, @TransDate,
                            @AddedBy, 0, GETDATE(), GETDATE()
                        )", conn, txn);
                    expCmd.Parameters.AddWithValue("@ExpenseId", expenseId);
                    expCmd.Parameters.AddWithValue("@Date", master.TransDate);
                    expCmd.Parameters.AddWithValue("@Mode", master.Mode ?? "");
                    expCmd.Parameters.AddWithValue("@Head", head.Head);
                    expCmd.Parameters.AddWithValue("@FundPool", fundPoolCode);
                    expCmd.Parameters.AddWithValue("@FundPoolName", master.FundPoolName ?? "");
                    expCmd.Parameters.AddWithValue("@Amount", head.Amount);
                    expCmd.Parameters.AddWithValue("@Nature", master.Nature ?? "");
                    expCmd.Parameters.AddWithValue("@CampId", (object?)master.CampId ?? DBNull.Value);
                    expCmd.Parameters.AddWithValue("@CampName", master.CampName ?? "");
                    expCmd.Parameters.AddWithValue("@RecipientRole", master.RecipientRole ?? "");
                    expCmd.Parameters.AddWithValue("@RecipientId", (object?)master.RecipientId ?? DBNull.Value);
                    expCmd.Parameters.AddWithValue("@RecipientName", master.RecipientName ?? "");
                    expCmd.Parameters.AddWithValue("@Purpose", head.Purpose ?? master.Purpose ?? "");
                    expCmd.Parameters.AddWithValue("@AccountId", accountId);
                    expCmd.Parameters.AddWithValue("@VoucherNo", voucherNo);
                    expCmd.Parameters.AddWithValue("@TransDate", master.TransDate);
                    expCmd.Parameters.AddWithValue("@AddedBy", (object?)userId ?? DBNull.Value);
                    await expCmd.ExecuteNonQueryAsync();
                }
            }

            await txn.CommitAsync();
            return master.Id;
        }
        catch
        {
            await txn.RollbackAsync();
            throw;
        }
    }

    public async Task<bool> UpdateAsync(int id, AccountMaster master, List<AccountMasterHeadItem> heads, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var txn = (SqlTransaction)await conn.BeginTransactionAsync();

        try
        {
            // Get existing AccountId
            string accountId = "", voucherNo = "", fundPoolCode = "";
            await using (var getCmd = new SqlCommand("SELECT AccountId, VoucherNo, FundPool FROM AccountMasters WHERE Id=@Id AND IsDeleted=0", conn, txn))
            {
                getCmd.Parameters.AddWithValue("@Id", id);
                await using var r = await getCmd.ExecuteReaderAsync();
                if (!await r.ReadAsync()) { await txn.RollbackAsync(); return false; }
                accountId = r.GetString(0);
                voucherNo = r.GetString(1);
                fundPoolCode = r.IsDBNull(2) ? "" : r.GetString(2);
            }

            // Resolve new FundPool code
            var newFundPoolCode = master.FundPool ?? fundPoolCode;
            var totalAmount = heads.Sum(h => h.Amount);
            var paymentType = heads.All(h => h.PaymentType == "Income") ? "Income"
                : heads.All(h => h.PaymentType == "Expense") ? "Expense" : "Mixed";

            // 1. UPDATE AccountMasters
            await using (var updCmd = new SqlCommand(@"
                UPDATE AccountMasters SET
                    TransDate=@TransDate, PaymentType=@PaymentType,
                    Mode=@Mode, FundPool=@FundPool, FundPoolName=@FundPoolName,
                    Amount=@Amount, Nature=@Nature,
                    RecipientRole=@RecipientRole, RecipientId=@RecipientId,
                    RecipientName=@RecipientName, Purpose=@Purpose,
                    UpdatedBy=@UpdatedBy, UpdatedAt=GETDATE()
                WHERE Id=@Id", conn, txn))
            {
                updCmd.Parameters.AddWithValue("@Id", id);
                updCmd.Parameters.AddWithValue("@TransDate", master.TransDate);
                updCmd.Parameters.AddWithValue("@PaymentType", paymentType);
                updCmd.Parameters.AddWithValue("@Mode", master.Mode ?? "");
                updCmd.Parameters.AddWithValue("@FundPool", newFundPoolCode);
                updCmd.Parameters.AddWithValue("@FundPoolName", master.FundPoolName ?? "");
                updCmd.Parameters.AddWithValue("@Amount", totalAmount);
                updCmd.Parameters.AddWithValue("@Nature", master.Nature ?? "");
                updCmd.Parameters.AddWithValue("@RecipientRole", master.RecipientRole ?? "");
                updCmd.Parameters.AddWithValue("@RecipientId", (object?)master.RecipientId ?? DBNull.Value);
                updCmd.Parameters.AddWithValue("@RecipientName", master.RecipientName ?? "");
                updCmd.Parameters.AddWithValue("@Purpose", master.Purpose ?? "");
                updCmd.Parameters.AddWithValue("@UpdatedBy", (object?)userId ?? DBNull.Value);
                await updCmd.ExecuteNonQueryAsync();
            }

            // 2. Soft-delete old linked Incomes & Expenses
            await using (var delInc = new SqlCommand("UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETDATE() WHERE AccountId=@AccId AND IsDeleted=0", conn, txn))
            { delInc.Parameters.AddWithValue("@AccId", accountId); await delInc.ExecuteNonQueryAsync(); }

            await using (var delExp = new SqlCommand("UPDATE Expenses SET IsDeleted=1, UpdatedAt=GETDATE() WHERE AccountId=@AccId AND IsDeleted=0", conn, txn))
            { delExp.Parameters.AddWithValue("@AccId", accountId); await delExp.ExecuteNonQueryAsync(); }

            // 3. Re-insert new heads
            foreach (var head in heads)
            {
                if (head.PaymentType == "Income")
                {
                    string incomeId = "";
                    await using (var idCmd = new SqlCommand("SELECT 'INC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS VARCHAR),6)", conn, txn))
                    { incomeId = (string)(await idCmd.ExecuteScalarAsync())!; }

                    await using var incCmd = new SqlCommand(@"
                        INSERT INTO Incomes(IncomeId,[Date],Mode,Head,FundPool,FundPoolName,Amount,Purpose,Source,SourceRef,
                            CampId,CampName,AccountId,VoucherNo,TransDate,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
                        VALUES(@IncId,@Date,@Mode,@Head,@FPool,@FPName,@Amt,@Purpose,'Manual','',
                            @CampId,@CampName,@AccId,@VchNo,@TransDate,@AddedBy,0,GETDATE(),GETDATE())", conn, txn);
                    incCmd.Parameters.AddWithValue("@IncId", incomeId);
                    incCmd.Parameters.AddWithValue("@Date", master.TransDate);
                    incCmd.Parameters.AddWithValue("@Mode", master.Mode ?? "");
                    incCmd.Parameters.AddWithValue("@Head", head.Head);
                    incCmd.Parameters.AddWithValue("@FPool", newFundPoolCode);
                    incCmd.Parameters.AddWithValue("@FPName", master.FundPoolName ?? "");
                    incCmd.Parameters.AddWithValue("@Amt", head.Amount);
                    incCmd.Parameters.AddWithValue("@Purpose", head.Purpose ?? master.Purpose ?? "");
                    incCmd.Parameters.AddWithValue("@CampId", (object?)master.CampId ?? DBNull.Value);
                    incCmd.Parameters.AddWithValue("@CampName", master.CampName ?? "");
                    incCmd.Parameters.AddWithValue("@AccId", accountId);
                    incCmd.Parameters.AddWithValue("@VchNo", voucherNo);
                    incCmd.Parameters.AddWithValue("@TransDate", master.TransDate);
                    incCmd.Parameters.AddWithValue("@AddedBy", (object?)userId ?? DBNull.Value);
                    await incCmd.ExecuteNonQueryAsync();
                }
                else if (head.PaymentType == "Expense")
                {
                    string expenseId = "";
                    await using (var idCmd = new SqlCommand("SELECT 'EXP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS VARCHAR),6)", conn, txn))
                    { expenseId = (string)(await idCmd.ExecuteScalarAsync())!; }

                    await using var expCmd = new SqlCommand(@"
                        INSERT INTO Expenses(ExpenseId,[Date],Mode,Head,FundPool,FundPoolName,Amount,Nature,
                            CampId,CampName,RecipientRole,RecipientId,RecipientName,Purpose,
                            AccountId,VoucherNo,TransDate,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
                        VALUES(@ExpId,@Date,@Mode,@Head,@FPool,@FPName,@Amt,@Nature,
                            @CampId,@CampName,@Role,@RecId,@RecName,@Purpose,
                            @AccId,@VchNo,@TransDate,@AddedBy,0,GETDATE(),GETDATE())", conn, txn);
                    expCmd.Parameters.AddWithValue("@ExpId", expenseId);
                    expCmd.Parameters.AddWithValue("@Date", master.TransDate);
                    expCmd.Parameters.AddWithValue("@Mode", master.Mode ?? "");
                    expCmd.Parameters.AddWithValue("@Head", head.Head);
                    expCmd.Parameters.AddWithValue("@FPool", newFundPoolCode);
                    expCmd.Parameters.AddWithValue("@FPName", master.FundPoolName ?? "");
                    expCmd.Parameters.AddWithValue("@Amt", head.Amount);
                    expCmd.Parameters.AddWithValue("@Nature", master.Nature ?? "");
                    expCmd.Parameters.AddWithValue("@CampId", (object?)master.CampId ?? DBNull.Value);
                    expCmd.Parameters.AddWithValue("@CampName", master.CampName ?? "");
                    expCmd.Parameters.AddWithValue("@Role", master.RecipientRole ?? "");
                    expCmd.Parameters.AddWithValue("@RecId", (object?)master.RecipientId ?? DBNull.Value);
                    expCmd.Parameters.AddWithValue("@RecName", master.RecipientName ?? "");
                    expCmd.Parameters.AddWithValue("@Purpose", head.Purpose ?? master.Purpose ?? "");
                    expCmd.Parameters.AddWithValue("@AccId", accountId);
                    expCmd.Parameters.AddWithValue("@VchNo", voucherNo);
                    expCmd.Parameters.AddWithValue("@TransDate", master.TransDate);
                    expCmd.Parameters.AddWithValue("@AddedBy", (object?)userId ?? DBNull.Value);
                    await expCmd.ExecuteNonQueryAsync();
                }
            }

            await txn.CommitAsync();
            return true;
        }
        catch
        {
            await txn.RollbackAsync();
            throw;
        }
    }

    public async Task<bool> DeleteAsync(int id, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var txn = (SqlTransaction)await conn.BeginTransactionAsync();

        try
        {
            // Get AccountId
            string accountId = "";
            await using (var getCmd = new SqlCommand("SELECT AccountId FROM AccountMasters WHERE Id=@Id AND IsDeleted=0", conn, txn))
            {
                getCmd.Parameters.AddWithValue("@Id", id);
                var result = await getCmd.ExecuteScalarAsync();
                if (result == null) { await txn.RollbackAsync(); return false; }
                accountId = (string)result;
            }

            // 1. Soft-delete linked Incomes
            await using (var cmd = new SqlCommand("UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETDATE() WHERE AccountId=@AccId AND IsDeleted=0", conn, txn))
            { cmd.Parameters.AddWithValue("@AccId", accountId); await cmd.ExecuteNonQueryAsync(); }

            // 2. Soft-delete linked Expenses
            await using (var cmd = new SqlCommand("UPDATE Expenses SET IsDeleted=1, UpdatedAt=GETDATE() WHERE AccountId=@AccId AND IsDeleted=0", conn, txn))
            { cmd.Parameters.AddWithValue("@AccId", accountId); await cmd.ExecuteNonQueryAsync(); }

            // 3. Soft-delete AccountMaster
            await using (var cmd = new SqlCommand("UPDATE AccountMasters SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETDATE() WHERE Id=@Id", conn, txn))
            {
                cmd.Parameters.AddWithValue("@Id", id);
                cmd.Parameters.AddWithValue("@DeletedBy", (object?)userId ?? DBNull.Value);
                await cmd.ExecuteNonQueryAsync();
            }

            await txn.CommitAsync();
            return true;
        }
        catch
        {
            await txn.RollbackAsync();
            throw;
        }
    }

    public async Task<List<(int Id, string PaymentType, string Head, decimal Amount, string Purpose, string RefId, int? CampId, string CampName)>> GetHeadsByAccountIdAsync(string accountId)
    {
        var result = new List<(int, string, string, decimal, string, string, int?, string)>();
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Get Incomes
        await using (var cmd = new SqlCommand("SELECT Id, Head, Amount, Purpose, IncomeId, CampId, ISNULL(CampName,'') FROM Incomes WHERE AccountId=@AccId AND IsDeleted=0", conn))
        {
            cmd.Parameters.AddWithValue("@AccId", accountId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                result.Add((r.GetInt32(0), "Income", r.IsDBNull(1) ? "" : r.GetString(1), r.GetDecimal(2), r.IsDBNull(3) ? "" : r.GetString(3), r.IsDBNull(4) ? "" : r.GetString(4), r.IsDBNull(5) ? null : r.GetInt32(5), r.GetString(6)));
        }

        // Get Expenses
        await using (var cmd = new SqlCommand("SELECT Id, Head, Amount, Purpose, ExpenseId, CampId, ISNULL(CampName,'') FROM Expenses WHERE AccountId=@AccId AND IsDeleted=0", conn))
        {
            cmd.Parameters.AddWithValue("@AccId", accountId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                result.Add((r.GetInt32(0), "Expense", r.IsDBNull(1) ? "" : r.GetString(1), r.GetDecimal(2), r.IsDBNull(3) ? "" : r.GetString(3), r.IsDBNull(4) ? "" : r.GetString(4), r.IsDBNull(5) ? null : r.GetInt32(5), r.GetString(6)));
        }

        return result;
    }

    private static void AddFilterParams(SqlCommand cmd, AccountMasterListRequest req)
    {
        if (!string.IsNullOrEmpty(req.PaymentType)) cmd.Parameters.AddWithValue("@PaymentType", req.PaymentType);
        if (!string.IsNullOrEmpty(req.Nature))      cmd.Parameters.AddWithValue("@Nature", req.Nature);
        if (req.RecipientId.HasValue)               cmd.Parameters.AddWithValue("@RecipientId", req.RecipientId.Value);
        if (!string.IsNullOrEmpty(req.DateFrom) && DateTime.TryParse(req.DateFrom, out var df))
            cmd.Parameters.AddWithValue("@DateFrom", df.Date);
        if (!string.IsNullOrEmpty(req.DateTo) && DateTime.TryParse(req.DateTo, out var dt))
            cmd.Parameters.AddWithValue("@DateTo", dt.Date);
        if (!string.IsNullOrEmpty(req.SearchText))
            cmd.Parameters.AddWithValue("@Search", "%" + req.SearchText + "%");
    }

    private static AccountMaster Map(SqlDataReader r) => new()
    {
        Id            = r.GetInt32(r.GetOrdinal("Id")),
        AccountId     = r.IsDBNull(r.GetOrdinal("AccountId"))     ? "" : r.GetString(r.GetOrdinal("AccountId")),
        VoucherNo     = r.IsDBNull(r.GetOrdinal("VoucherNo"))     ? "" : r.GetString(r.GetOrdinal("VoucherNo")),
        TransDate     = r.GetDateTime(r.GetOrdinal("TransDate")),
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
