using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class OwnerPaymentRepository : IOwnerPaymentRepository
{
    private readonly IDbConnectionFactory _factory;
    public OwnerPaymentRepository(IDbConnectionFactory factory) => _factory = factory;

    // ══════════════════════════════════════════════════════════════════════════
    //  GET SUMMARY
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<OwnerPaymentSummaryResponse?> GetSummaryAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerPaymentSummary", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;

        var totalPayable = r.IsDBNull(r.GetOrdinal("TotalPayable")) ? 0 : r.GetDecimal(r.GetOrdinal("TotalPayable"));
        var totalPaid = r.IsDBNull(r.GetOrdinal("TotalPaidToOwner")) ? 0 : r.GetDecimal(r.GetOrdinal("TotalPaidToOwner"));

        return new OwnerPaymentSummaryResponse
        {
            OwnerContractId  = ownerContractId,
            OcCode           = SafeStr(r, "OcCode"),
            OwnerId          = r.GetInt32(r.GetOrdinal("OwnerId")),
            OwnerName        = SafeStr(r, "OwnerName"),
            CampId           = r.GetInt32(r.GetOrdinal("CampId")),
            CampName         = SafeStr(r, "CampName"),
            StartDate        = SafeStr(r, "StartDate"),
            EndDate          = SafeStr(r, "EndDate"),
            TotalPayable     = Math.Round(totalPayable, 2),
            TotalPaidToOwner = Math.Round(totalPaid, 2),
            BalanceDueToOwner = Math.Round(totalPayable - totalPaid, 2),
            MonthlyRent      = Math.Round(r.IsDBNull(r.GetOrdinal("MonthlyRent")) ? 0 : r.GetDecimal(r.GetOrdinal("MonthlyRent")), 2),
            NoOfMonths       = r.IsDBNull(r.GetOrdinal("NoOfMonths")) ? 0 : r.GetInt32(r.GetOrdinal("NoOfMonths")),
            TotalInstallments = r.IsDBNull(r.GetOrdinal("TotalInstallments")) ? 0 : r.GetInt32(r.GetOrdinal("TotalInstallments")),
            PaidCount        = r.IsDBNull(r.GetOrdinal("PaidCount")) ? 0 : r.GetInt32(r.GetOrdinal("PaidCount")),
            PendingCount     = r.IsDBNull(r.GetOrdinal("PendingCount")) ? 0 : r.GetInt32(r.GetOrdinal("PendingCount")),
            PartialCount     = r.IsDBNull(r.GetOrdinal("PartialCount")) ? 0 : r.GetInt32(r.GetOrdinal("PartialCount")),
            PaymentProgress  = totalPayable > 0 ? Math.Round(totalPaid / totalPayable * 100, 2) : 0.00m,
            SecurityDeposit  = Math.Round(r.IsDBNull(r.GetOrdinal("SecurityDeposit")) ? 0 : r.GetDecimal(r.GetOrdinal("SecurityDeposit")), 2),
            SecurityDepositPaid = Math.Round(r.IsDBNull(r.GetOrdinal("SecurityDepositPaid")) ? 0 : r.GetDecimal(r.GetOrdinal("SecurityDepositPaid")), 2),
            PaymentType      = SafeStr(r, "PaymentType"),
            Status           = SafeStr(r, "Status"),
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET HISTORY
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<IEnumerable<OwnerPaymentHistoryResponse>> GetHistoryAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerPaymentHistory", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);

        var list = new List<OwnerPaymentHistoryResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new OwnerPaymentHistoryResponse
            {
                Id              = r.GetInt32(r.GetOrdinal("Id")),
                TxnCode         = SafeStr(r, "TxnCode"),
                OwnerContractId = ownerContractId,
                OcCode          = SafeStr(r, "OcCode"),
                Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
                Date            = SafeStr(r, "Date"),
                Description     = SafeStr(r, "Description"),
                InstallmentNos  = SafeStr(r, "InstallmentNos"),
                PaymentMode     = SafeStr(r, "PaymentMode"),
                ReferenceNo     = SafeStr(r, "ReferenceNo"),
                PaidBy          = SafeStr(r, "PaidBy"),
                FundPoolName    = SafeStr(r, "FundPoolName"),
                ExpenseId       = r.IsDBNull(r.GetOrdinal("ExpenseId")) ? null : r.GetInt32(r.GetOrdinal("ExpenseId")),
                Type            = SafeStr(r, "Type"),
                CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
            });
        }
        return list;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  PAY OWNER
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<(bool Success, string TxnCode, int? ExpenseId)> PayOwnerAsync(PayOwnerRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var OcCode = ""; var OwnerId = 0; var CampId = 0;
        var OwnerName = ""; var CampName = ""; var FundPoolCode = "";

        // Get contract info
        await using (var infoCmd = new SqlCommand(
            @"SELECT oc.OcCode, oc.OwnerId, oc.CampId, ISNULL(o.Name,'') AS OwnerName, ISNULL(c.Name,'') AS CampName
              FROM OwnerContracts oc LEFT JOIN Owners o ON o.Id=oc.OwnerId LEFT JOIN Camps c ON c.Id=oc.CampId
              WHERE oc.Id=@Id", conn))
        {
            infoCmd.Parameters.AddWithValue("@Id", request.OwnerContractId);
            await using var rInfo = await infoCmd.ExecuteReaderAsync();
            if (await rInfo.ReadAsync())
            {
                OcCode = rInfo.GetString(0); OwnerId = rInfo.GetInt32(1); CampId = rInfo.GetInt32(2);
                OwnerName = rInfo.GetString(3); CampName = rInfo.GetString(4);
            }
        }

        // Get FundPool Code
        if (request.FundPoolId.HasValue)
        {
            await using var fpCmd = new SqlCommand("SELECT Code, Name FROM FundPools WHERE Id=@Id", conn);
            fpCmd.Parameters.AddWithValue("@Id", request.FundPoolId.Value);
            await using var rFp = await fpCmd.ExecuteReaderAsync();
            if (await rFp.ReadAsync()) { FundPoolCode = rFp.GetString(0); request.FundPoolName = rFp.GetString(1); }
        }

        // Build InstallmentNos from MonthlyPayments if provided
        var installmentNos = request.InstallmentNos ?? "";
        if (request.MonthlyPayments != null && request.MonthlyPayments.Count > 0 && string.IsNullOrEmpty(installmentNos))
        {
            installmentNos = string.Join(",", request.MonthlyPayments.Select(m => m.InstallmentNo));
        }

        var txn = (Microsoft.Data.SqlClient.SqlTransaction)await conn.BeginTransactionAsync();
        try
        {
            // 1. Generate TxnCode
            int nextId = 0;
            await using (var maxCmd = new SqlCommand("SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions", conn, txn))
            { nextId = (int)(await maxCmd.ExecuteScalarAsync())!; }
            var txnCode = "OPY-" + nextId.ToString().PadLeft(6, '0');

            // 2. Insert OwnerTransaction
            await using (var insCmd = new SqlCommand(@"
                INSERT INTO OwnerTransactions (TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
                    Type, Amount, Date, Description, InstallmentNos, PaymentMode, ReferenceNo, CreatedAt)
                VALUES (@TxnCode, @OcId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
                    'CR', @Amount, @PaidDate, @Desc, @InstNos, @PayMode, @RefNo, GETDATE())", conn, txn))
            {
                insCmd.Parameters.AddWithValue("@TxnCode", txnCode);
                insCmd.Parameters.AddWithValue("@OcId", request.OwnerContractId);
                insCmd.Parameters.AddWithValue("@OcCode", OcCode);
                insCmd.Parameters.AddWithValue("@CampId", CampId);
                insCmd.Parameters.AddWithValue("@CampName", CampName);
                insCmd.Parameters.AddWithValue("@OwnerId", OwnerId);
                insCmd.Parameters.AddWithValue("@OwnerName", OwnerName);
                insCmd.Parameters.AddWithValue("@Amount", request.Amount);
                insCmd.Parameters.AddWithValue("@PaidDate", request.PaidDate);
                insCmd.Parameters.AddWithValue("@Desc", string.IsNullOrEmpty(request.Notes) ? $"Payment to owner - {request.PaymentMode}" : request.Notes);
                insCmd.Parameters.AddWithValue("@InstNos", installmentNos);
                insCmd.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                insCmd.Parameters.AddWithValue("@RefNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                await insCmd.ExecuteNonQueryAsync();
            }

            // 3. Process MonthlyPayments array — update OwnerMonthlyContractInstallments per month
            if (request.MonthlyPayments != null && request.MonthlyPayments.Count > 0)
            {
                foreach (var mp in request.MonthlyPayments)
                {
                    if (mp.Amount <= 0) continue;

                    // Update OwnerMonthlyContractInstallments for this installment
                    await using var updMci = new SqlCommand(@"
                        UPDATE OwnerMonthlyContractInstallments
                        SET PaidAmount = ISNULL(PaidAmount, 0) + @Amount,
                            Balance = CASE WHEN Balance - @Amount < 0 THEN 0 ELSE Balance - @Amount END,
                            PaidDate = @PaidDate,
                            PaymentMode = @PayMode,
                            PaymentStatus = CASE WHEN (ISNULL(PaidAmount,0) + @Amount) >= Amount THEN 'Paid'
                                                 WHEN (ISNULL(PaidAmount,0) + @Amount) > 0 THEN 'Partial'
                                                 ELSE 'Pending' END,
                            Status = CASE WHEN (ISNULL(PaidAmount,0) + @Amount) >= Amount THEN 'Paid'
                                          WHEN (ISNULL(PaidAmount,0) + @Amount) > 0 THEN 'Partial'
                                          ELSE 'Pending' END,
                            ReferenceNo = @RefNo,
                            UpdatedAt = GETDATE()
                        WHERE OwnerContractId = @OcId AND InstallmentNo = @InstNo AND ISNULL(IsDeleted,0)=0", conn, txn);
                    updMci.Parameters.AddWithValue("@OcId", request.OwnerContractId);
                    updMci.Parameters.AddWithValue("@InstNo", mp.InstallmentNo);
                    updMci.Parameters.AddWithValue("@Amount", mp.Amount);
                    updMci.Parameters.AddWithValue("@PaidDate", request.PaidDate);
                    updMci.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                    updMci.Parameters.AddWithValue("@RefNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                    await updMci.ExecuteNonQueryAsync();
                }
            }
            else if (!string.IsNullOrEmpty(installmentNos))
            {
                // Fallback: distribute total amount across installments sequentially
                var remaining = request.Amount;
                var instNums = installmentNos.Split(',').Where(s => int.TryParse(s, out _)).Select(int.Parse).OrderBy(n => n);
                foreach (var instNo in instNums)
                {
                    if (remaining <= 0) break;
                    decimal instBalance = 0;
                    await using (var balCmd = new SqlCommand(
                        "SELECT Balance FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, txn))
                    {
                        balCmd.Parameters.AddWithValue("@OcId", request.OwnerContractId);
                        balCmd.Parameters.AddWithValue("@No", instNo);
                        var bal = await balCmd.ExecuteScalarAsync();
                        instBalance = bal != null && bal != DBNull.Value ? (decimal)bal : 0;
                    }
                    if (instBalance <= 0) continue;
                    var payThis = Math.Min(remaining, instBalance);

                    await using var updCmd = new SqlCommand(@"
                        UPDATE OwnerMonthlyContractInstallments
                        SET PaidAmount = ISNULL(PaidAmount,0) + @Amt,
                            Balance = CASE WHEN Balance - @Amt < 0 THEN 0 ELSE Balance - @Amt END,
                            PaidDate = @PaidDate, PaymentMode = @PayMode,
                            Status = CASE WHEN (ISNULL(PaidAmount,0)+@Amt) >= Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END,
                            PaymentStatus = CASE WHEN (ISNULL(PaidAmount,0)+@Amt) >= Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END,
                            ReferenceNo = @RefNo, UpdatedAt = GETDATE()
                        WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, txn);
                    updCmd.Parameters.AddWithValue("@OcId", request.OwnerContractId);
                    updCmd.Parameters.AddWithValue("@No", instNo);
                    updCmd.Parameters.AddWithValue("@Amt", payThis);
                    updCmd.Parameters.AddWithValue("@PaidDate", request.PaidDate);
                    updCmd.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                    updCmd.Parameters.AddWithValue("@RefNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                    await updCmd.ExecuteNonQueryAsync();
                    remaining -= payThis;
                }
            }

            // 4. Update OwnerInstallments — distribute total amount sequentially from first unpaid
            {
                var remaining2 = request.Amount;
                await using var oiListCmd = new SqlCommand(
                    "SELECT No, Amount, ISNULL(PaidAmount,0) AS PaidAmount FROM OwnerInstallments WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND (Amount - ISNULL(PaidAmount,0)) > 0 ORDER BY No", conn, txn);
                oiListCmd.Parameters.AddWithValue("@OcId", request.OwnerContractId);
                var unpaidInstallments = new List<(int No, decimal Balance)>();
                await using (var rOi = await oiListCmd.ExecuteReaderAsync())
                {
                    while (await rOi.ReadAsync())
                        unpaidInstallments.Add((rOi.GetInt32(0), rOi.GetDecimal(1) - rOi.GetDecimal(2)));
                }

                foreach (var (instNo, oiBal) in unpaidInstallments)
                {
                    if (remaining2 <= 0) break;
                    if (oiBal <= 0) continue;
                    var payThis = Math.Min(remaining2, oiBal);

                    await using var updOi = new SqlCommand(@"
                        UPDATE OwnerInstallments
                        SET PaidAmount = ISNULL(PaidAmount,0) + @Amt,
                            PaidDate = @PaidDate, PaymentMode = @PayMode,
                            ReferenceNo = @RefNo,
                            Status = CASE WHEN (ISNULL(PaidAmount,0)+@Amt) >= Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END
                        WHERE OwnerContractId=@OcId AND No=@No AND ISNULL(IsDeleted,0)=0", conn, txn);
                    updOi.Parameters.AddWithValue("@OcId", request.OwnerContractId);
                    updOi.Parameters.AddWithValue("@No", instNo);
                    updOi.Parameters.AddWithValue("@Amt", payThis);
                    updOi.Parameters.AddWithValue("@PaidDate", request.PaidDate);
                    updOi.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                    updOi.Parameters.AddWithValue("@RefNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                    await updOi.ExecuteNonQueryAsync();
                    remaining2 -= payThis;
                }
            }

            // 5. Insert Expense
            var expId = ""; int expenseId = 0;
            await using (var expSeqCmd = new SqlCommand("SELECT 'EXP-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS VARCHAR),6)", conn, txn))
            { expId = (string)(await expSeqCmd.ExecuteScalarAsync())!; }

            await using (var expCmd = new SqlCommand(@"
                INSERT INTO Expenses(ExpenseId, Date, Mode, Head, FundPool, FundPoolName, Amount, Nature,
                    CampId, CampName, RecipientRole, RecipientName, Purpose, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
                VALUES(@ExpId, @Date, @Mode, 'Owner Payment', @FPool, @FPoolName, @Amount, 'Camp',
                    @CampId, @CampName, 'Owner', @OwnerName, @Purpose, @AddedBy, 0, GETDATE(), GETDATE());
                SELECT SCOPE_IDENTITY();", conn, txn))
            {
                expCmd.Parameters.AddWithValue("@ExpId", expId);
                expCmd.Parameters.AddWithValue("@Date", request.PaidDate);
                expCmd.Parameters.AddWithValue("@Mode", request.PaymentMode ?? "Cash");
                expCmd.Parameters.AddWithValue("@FPool", FundPoolCode);
                expCmd.Parameters.AddWithValue("@FPoolName", request.FundPoolName ?? "");
                expCmd.Parameters.AddWithValue("@Amount", request.Amount);
                expCmd.Parameters.AddWithValue("@CampId", CampId);
                expCmd.Parameters.AddWithValue("@CampName", CampName);
                expCmd.Parameters.AddWithValue("@OwnerName", OwnerName);
                expCmd.Parameters.AddWithValue("@Purpose", $"Owner Payment - {OcCode} - Inst: {installmentNos}");
                expCmd.Parameters.AddWithValue("@AddedBy", (object?)request.AddedBy ?? DBNull.Value);
                var result = await expCmd.ExecuteScalarAsync();
                expenseId = result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
            }

            // 6. Update OwnerTransaction with ExpenseId
            await using (var updTxn = new SqlCommand("UPDATE OwnerTransactions SET ExpenseId=@ExpId WHERE TxnCode=@TxnCode", conn, txn))
            {
                updTxn.Parameters.AddWithValue("@ExpId", expenseId);
                updTxn.Parameters.AddWithValue("@TxnCode", txnCode);
                await updTxn.ExecuteNonQueryAsync();
            }

            // 7. Deduct from FundPool
            if (request.FundPoolId.HasValue)
            {
                await using var fpCmd = new SqlCommand("UPDATE FundPools SET Balance=Balance-@Amt, UpdatedAt=GETDATE() WHERE Id=@Id", conn, txn);
                fpCmd.Parameters.AddWithValue("@Amt", request.Amount);
                fpCmd.Parameters.AddWithValue("@Id", request.FundPoolId.Value);
                await fpCmd.ExecuteNonQueryAsync();
            }

            // 8. Update OwnerContracts timestamp
            await using (var tsCmd = new SqlCommand("UPDATE OwnerContracts SET UpdatedAt=GETDATE() WHERE Id=@Id", conn, txn))
            {
                tsCmd.Parameters.AddWithValue("@Id", request.OwnerContractId);
                await tsCmd.ExecuteNonQueryAsync();
            }

            await txn.CommitAsync();
            return (true, txnCode, expenseId > 0 ? expenseId : null);
        }
        catch (Exception ex)
        {
            await txn.RollbackAsync();
            Console.Error.WriteLine($"[OwnerPaymentRepo] PayOwner failed: {ex.Message}");
            return (false, "", null);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  DELETE PAYMENT (REVERSE)
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<bool> DeletePaymentAsync(int txnId, int? deletedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteOwnerPayment", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@TxnId",     txnId);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);

        try
        {
            await cmd.ExecuteNonQueryAsync();
            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[OwnerPaymentRepo] DeletePayment failed: {ex.Message}");
            return false;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET PAYMENT EDIT DATA (txnId → payment + monthly breakdown for edit)
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<OwnerPaymentEditDataResponse?> GetPaymentEditDataAsync(int txnId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        OwnerPaymentEditDataResponse? result = null;
        int ownerContractId = 0;
        string installmentNos = "";

        // 1. Get transaction info
        await using (var cmd = new SqlCommand(@"
            SELECT t.Id, t.TxnCode, t.OwnerContractId, t.OcCode, t.Amount,
                   CONVERT(VARCHAR(10),t.Date,120) AS Date,
                   ISNULL(t.PaymentMode,'') AS PaymentMode,
                   ISNULL(t.ReferenceNo,'') AS ReferenceNo,
                   ISNULL(t.Description,'') AS Description,
                   ISNULL(t.InstallmentNos,'') AS InstallmentNos,
                   t.ExpenseId
            FROM OwnerTransactions t WHERE t.Id=@TxnId AND ISNULL(t.IsDeleted,0)=0", conn))
        {
            cmd.Parameters.AddWithValue("@TxnId", txnId);
            await using var r = await cmd.ExecuteReaderAsync();
            if (!await r.ReadAsync()) return null;

            ownerContractId = r.GetInt32(r.GetOrdinal("OwnerContractId"));
            installmentNos  = SafeStr(r, "InstallmentNos");

            result = new OwnerPaymentEditDataResponse
            {
                TxnId           = txnId,
                TxnCode         = SafeStr(r, "TxnCode"),
                OwnerContractId = ownerContractId,
                OcCode          = SafeStr(r, "OcCode"),
                Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
                Date            = SafeStr(r, "Date"),
                PaymentMode     = SafeStr(r, "PaymentMode"),
                ReferenceNo     = SafeStr(r, "ReferenceNo"),
                Description     = SafeStr(r, "Description"),
                InstallmentNos  = installmentNos,
                PaidBy          = SafeStr(r, "Description"),
                ExpenseId       = r.IsDBNull(r.GetOrdinal("ExpenseId")) ? null : r.GetInt32(r.GetOrdinal("ExpenseId")),
            };
        }

        // 2. Get FundPool from Expense
        if (result!.ExpenseId.HasValue)
        {
            await using var fpCmd = new SqlCommand(@"
                SELECT e.FundPool, e.FundPoolName,
                       ISNULL((SELECT Id FROM FundPools WHERE Code=e.FundPool AND ISNULL(IsDeleted,0)=0), 0) AS FundPoolId
                FROM Expenses e WHERE e.Id=@Id", conn);
            fpCmd.Parameters.AddWithValue("@Id", result.ExpenseId.Value);
            await using var rFp = await fpCmd.ExecuteReaderAsync();
            if (await rFp.ReadAsync())
            {
                result.FundPoolName = SafeStr(rFp, "FundPoolName");
                var fpId = rFp.GetInt32(rFp.GetOrdinal("FundPoolId"));
                result.FundPoolId = fpId > 0 ? fpId : null;
            }
        }

        // 3. Get monthly installments that were paid in this transaction
        if (!string.IsNullOrEmpty(installmentNos) && installmentNos != "0")
        {
            var inClause = string.Join(",", installmentNos.Split(',').Where(s => int.TryParse(s, out _)));
            if (!string.IsNullOrEmpty(inClause))
            {
                await using var mCmd = new SqlCommand($@"
                    SELECT Id, InstallmentNo, ISNULL(Month,'') AS Month,
                           CONVERT(VARCHAR(10),DueDate,120) AS DueDate,
                           Amount, PaidAmount, Balance,
                           ISNULL(Status,'Pending') AS Status
                    FROM OwnerMonthlyContractInstallments
                    WHERE OwnerContractId=@OcId
                      AND InstallmentNo IN ({inClause})
                      AND ISNULL(IsDeleted,0)=0
                    ORDER BY InstallmentNo", conn);
                mCmd.Parameters.AddWithValue("@OcId", ownerContractId);
                await using var rM = await mCmd.ExecuteReaderAsync();
                while (await rM.ReadAsync())
                {
                    result.MonthlyPayments.Add(new OwnerPaymentEditMonthItem
                    {
                        Id            = rM.GetInt32(rM.GetOrdinal("Id")),
                        InstallmentNo = rM.GetInt32(rM.GetOrdinal("InstallmentNo")),
                        Month         = SafeStr(rM, "Month"),
                        DueDate       = SafeStr(rM, "DueDate"),
                        Amount        = rM.GetDecimal(rM.GetOrdinal("Amount")),
                        PaidAmount    = rM.GetDecimal(rM.GetOrdinal("PaidAmount")),
                        Balance       = rM.GetDecimal(rM.GetOrdinal("Balance")),
                        Status        = SafeStr(rM, "Status"),
                    });
                }
            }
        }

        return result;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET VOUCHER
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<OwnerPaymentVoucherResponse?> GetVoucherAsync(int txnId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT t.Id, t.TxnCode, t.OcCode, t.OwnerName, t.CampName,
                   t.Amount, CONVERT(VARCHAR(10), t.Date, 120) AS Date,
                   ISNULL(t.PaymentMode,'') AS PaymentMode,
                   ISNULL(t.ReferenceNo,'') AS ReferenceNo,
                   ISNULL(t.Description,'') AS Description,
                   ISNULL(t.InstallmentNos,'') AS InstallmentNos,
                   ISNULL(t.Description,'') AS PaidBy,
                   '' AS FundPoolName
            FROM OwnerTransactions t
            WHERE t.Id = @TxnId AND ISNULL(t.IsDeleted,0)=0", conn);
        cmd.Parameters.AddWithValue("@TxnId", txnId);

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;

        return new OwnerPaymentVoucherResponse
        {
            TxnId          = r.GetInt32(r.GetOrdinal("Id")),
            TxnCode        = SafeStr(r, "TxnCode"),
            OcCode         = SafeStr(r, "OcCode"),
            OwnerName      = SafeStr(r, "OwnerName"),
            CampName       = SafeStr(r, "CampName"),
            Amount         = r.GetDecimal(r.GetOrdinal("Amount")),
            Date           = SafeStr(r, "Date"),
            PaymentMode    = SafeStr(r, "PaymentMode"),
            ReferenceNo    = SafeStr(r, "ReferenceNo"),
            Description    = SafeStr(r, "Description"),
            InstallmentNos = SafeStr(r, "InstallmentNos"),
            PaidBy         = SafeStr(r, "PaidBy"),
            FundPoolName   = SafeStr(r, "FundPoolName"),
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SECURITY DEPOSIT — STATUS
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<OwnerSecurityDepositStatusResponse?> GetSecurityDepositStatusAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT oc.Id, oc.OcCode, o.Name AS OwnerName, c.Name AS CampName,
                   ISNULL(oc.SecurityDeposit, 0) AS DepositAmount,
                   ISNULL(oc.SecurityDepositPaid, 0) AS DepositPaid
            FROM OwnerContracts oc
            JOIN Owners o ON o.Id = oc.OwnerId
            JOIN Camps c ON c.Id = oc.CampId
            WHERE oc.Id = @OwnerContractId AND ISNULL(oc.IsDeleted, 0) = 0", conn);
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;

        var amount = r.GetDecimal(r.GetOrdinal("DepositAmount"));
        var paid = r.GetDecimal(r.GetOrdinal("DepositPaid"));
        var pending = Math.Max(amount - paid, 0);

        string status = paid >= amount && amount > 0 ? "Paid"
                      : paid > 0 ? "Partially Paid"
                      : "Pending";

        return new OwnerSecurityDepositStatusResponse
        {
            OwnerContractId = ownerContractId,
            OcCode          = r.GetString(r.GetOrdinal("OcCode")),
            OwnerName       = SafeStr(r, "OwnerName"),
            CampName        = SafeStr(r, "CampName"),
            DepositAmount   = amount,
            DepositPaid     = paid,
            DepositPending  = pending,
            Status          = status,
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SECURITY DEPOSIT — PAY
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<(bool Success, decimal NewPaid, string NewStatus)> PaySecurityDepositAsync(PayOwnerSecurityDepositRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_PayOwnerSecurityDeposit", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@OwnerContractId", request.OwnerContractId);
        cmd.Parameters.AddWithValue("@Amount",          request.Amount);
        cmd.Parameters.AddWithValue("@PaidDate",        request.PaidDate);
        cmd.Parameters.AddWithValue("@PaymentMode",     request.PaymentMode ?? "Cash");
        cmd.Parameters.AddWithValue("@PaymentModeId",   (object?)request.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ChequeNumber",    request.ChequeNumber ?? "");
        cmd.Parameters.AddWithValue("@FundPoolId",      (object?)request.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",    request.FundPoolName ?? "");
        cmd.Parameters.AddWithValue("@PaidBy",          request.PaidBy ?? "Admin");
        cmd.Parameters.AddWithValue("@Notes",           request.Notes ?? "");

        var newPaidParam = new SqlParameter("@NewPaid", SqlDbType.Decimal) { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };
        var newStatusParam = new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newPaidParam);
        cmd.Parameters.Add(newStatusParam);

        try
        {
            await cmd.ExecuteNonQueryAsync();
            var newPaid = (decimal)newPaidParam.Value;
            var newStatus = newStatusParam.Value?.ToString() ?? "Paid";
            return (true, newPaid, newStatus);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[OwnerPaymentRepo] PaySecurityDeposit failed: {ex.Message}");
            return (false, 0, "Error");
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SECURITY DEPOSIT — SETTLE
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<(bool Success, string NewStatus)> SettleSecurityDepositAsync(SettleOwnerSecurityDepositRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_SettleOwnerSecurityDeposit", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@OwnerContractId", request.OwnerContractId);
        cmd.Parameters.AddWithValue("@RecoverAmount",   request.RecoverAmount);
        cmd.Parameters.AddWithValue("@AdjustAmount",    request.AdjustAmount);
        cmd.Parameters.AddWithValue("@ForfeitAmount",   request.ForfeitAmount);
        cmd.Parameters.AddWithValue("@FundPoolId",      (object?)request.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",    request.FundPoolName ?? "");
        cmd.Parameters.AddWithValue("@Notes",           request.Notes ?? "");
        cmd.Parameters.AddWithValue("@SettledBy",       request.SettledBy ?? "Admin");

        var newStatusParam = new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newStatusParam);

        try
        {
            await cmd.ExecuteNonQueryAsync();
            var newStatus = newStatusParam.Value?.ToString() ?? "Settled";
            return (true, newStatus);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[OwnerPaymentRepo] SettleSecurityDeposit failed: {ex.Message}");
            return (false, "Error");
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private static string SafeStr(SqlDataReader r, string col)
    {
        try { var o = r.GetOrdinal(col); return r.IsDBNull(o) ? "" : r.GetString(o); }
        catch { return ""; }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET ALL CONTRACTS (list for dropdown / paginated)
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<IEnumerable<OwnerContractListItemResponse>> GetAllContractsAsync(OwnerPaymentListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var sql = @"
            SELECT
                oc.Id,
                oc.OcCode,
                oc.OwnerId,
                ISNULL(o.Name,'') AS OwnerName,
                oc.CampId,
                ISNULL(c.Name,'') AS CampName,
                ISNULL(oc.PaymentType,'') AS PaymentType,
                oc.TotalAmount,
                ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0))
                        FROM OwnerInstallments oi
                        WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0),0) AS PaidAmount,
                oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0))
                        FROM OwnerInstallments oi
                        WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0),0) AS Balance,
                ISNULL(oc.MonthlyRent,0) AS MonthlyRent,
                ISNULL(oc.NoOfMonths,0) AS NoOfMonths,
                CONVERT(VARCHAR(10),oc.StartDate,120) AS StartDate,
                CASE WHEN oc.EndDate IS NOT NULL THEN CONVERT(VARCHAR(10),oc.EndDate,120) ELSE NULL END AS EndDate,
                ISNULL(oc.SecurityDeposit,0) AS SecurityDeposit,
                ISNULL(oc.SecurityDepositPaid,0) AS SecurityDepositPaid,
                CASE
                    WHEN EXISTS (SELECT 1 FROM OwnerTransactions t WHERE t.OwnerContractId=oc.Id AND t.Type='SD-SETTLE' AND ISNULL(t.IsDeleted,0)=0) THEN 'Settled'
                    WHEN ISNULL(oc.SecurityDeposit,0) = 0 THEN 'No SD'
                    WHEN ISNULL(oc.SecurityDepositPaid,0) >= ISNULL(oc.SecurityDeposit,0) THEN 'Paid'
                    WHEN ISNULL(oc.SecurityDepositPaid,0) > 0 THEN 'Partially Paid'
                    ELSE 'Pending'
                END AS SecurityDepositStatus,
                oc.Status
            FROM OwnerContracts oc
            LEFT JOIN Owners o ON o.Id=oc.OwnerId
            LEFT JOIN Camps  c ON c.Id=oc.CampId
            WHERE ISNULL(oc.IsDeleted,0)=0
              AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
              AND (@CampId  IS NULL OR oc.CampId=@CampId)
              AND (@Status  IS NULL OR oc.Status=@Status)
              AND (@Search  IS NULL OR oc.OcCode LIKE '%'+@Search+'%'
                                    OR o.Name    LIKE '%'+@Search+'%'
                                    OR c.Name    LIKE '%'+@Search+'%')
            ORDER BY oc.CreatedAt DESC";

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@OwnerId", (object?)request.OwnerId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",  (object?)request.CampId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",  (object?)request.Status  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Search",  string.IsNullOrEmpty(request.SearchText) ? (object)DBNull.Value : request.SearchText);

        var list = new List<OwnerContractListItemResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new OwnerContractListItemResponse
            {
                Id                   = r.GetInt32(r.GetOrdinal("Id")),
                OcCode               = SafeStr(r, "OcCode"),
                OwnerId              = r.GetInt32(r.GetOrdinal("OwnerId")),
                OwnerName            = SafeStr(r, "OwnerName"),
                CampId               = r.GetInt32(r.GetOrdinal("CampId")),
                CampName             = SafeStr(r, "CampName"),
                PaymentType          = SafeStr(r, "PaymentType"),
                TotalAmount          = r.GetDecimal(r.GetOrdinal("TotalAmount")),
                PaidAmount           = r.GetDecimal(r.GetOrdinal("PaidAmount")),
                Balance              = r.GetDecimal(r.GetOrdinal("Balance")),
                MonthlyRent          = r.GetDecimal(r.GetOrdinal("MonthlyRent")),
                NoOfMonths           = r.GetInt32(r.GetOrdinal("NoOfMonths")),
                StartDate            = SafeStr(r, "StartDate"),
                EndDate              = r.IsDBNull(r.GetOrdinal("EndDate")) ? null : r.GetString(r.GetOrdinal("EndDate")),
                SecurityDeposit      = r.GetDecimal(r.GetOrdinal("SecurityDeposit")),
                SecurityDepositPaid  = r.GetDecimal(r.GetOrdinal("SecurityDepositPaid")),
                SecurityDepositStatus = SafeStr(r, "SecurityDepositStatus"),
                Status               = SafeStr(r, "Status"),
            });
        }
        return list;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET PAYMENT BY ID
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<OwnerPaymentHistoryResponse?> GetPaymentByIdAsync(int txnId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT t.Id, t.TxnCode, t.OwnerContractId, t.OcCode, t.Amount,
                   CONVERT(VARCHAR(10),t.Date,120) AS Date,
                   ISNULL(t.Description,'') AS Description,
                   ISNULL(t.InstallmentNos,'') AS InstallmentNos,
                   ISNULL(t.PaymentMode,'') AS PaymentMode,
                   ISNULL(t.ReferenceNo,'') AS ReferenceNo,
                   ISNULL(t.Description,'') AS PaidBy,
                   '' AS FundPoolName,
                   t.ExpenseId,
                   ISNULL(t.Type,'CR') AS Type,
                   t.CreatedAt
            FROM OwnerTransactions t
            WHERE t.Id = @TxnId AND ISNULL(t.IsDeleted,0)=0", conn);
        cmd.Parameters.AddWithValue("@TxnId", txnId);

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;

        return new OwnerPaymentHistoryResponse
        {
            Id              = r.GetInt32(r.GetOrdinal("Id")),
            TxnCode         = SafeStr(r, "TxnCode"),
            OwnerContractId = r.GetInt32(r.GetOrdinal("OwnerContractId")),
            OcCode          = SafeStr(r, "OcCode"),
            Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
            Date            = SafeStr(r, "Date"),
            Description     = SafeStr(r, "Description"),
            InstallmentNos  = SafeStr(r, "InstallmentNos"),
            PaymentMode     = SafeStr(r, "PaymentMode"),
            ReferenceNo     = SafeStr(r, "ReferenceNo"),
            PaidBy          = SafeStr(r, "PaidBy"),
            FundPoolName    = SafeStr(r, "FundPoolName"),
            ExpenseId       = r.IsDBNull(r.GetOrdinal("ExpenseId")) ? null : r.GetInt32(r.GetOrdinal("ExpenseId")),
            Type            = SafeStr(r, "Type"),
            CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET INSTALLMENTS
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<IEnumerable<OwnerInstallmentDetailResponse>> GetInstallmentsAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT Id, OwnerContractId, InstallmentNo,
                   Amount, PaidAmount, Balance,
                   CONVERT(VARCHAR(10),DueDate,120) AS DueDate,
                   CASE WHEN PaidDate IS NOT NULL THEN CONVERT(VARCHAR(10),PaidDate,120) ELSE NULL END AS PaidDate,
                   ISNULL(Status,'Pending') AS Status,
                   ISNULL(PaymentMode,'') AS PaymentMode,
                   ISNULL(ReferenceNo,'') AS ReferenceNo,
                   ISNULL(Month,'') AS Month
            FROM OwnerMonthlyContractInstallments
            WHERE OwnerContractId=@OwnerContractId AND ISNULL(IsDeleted,0)=0
            ORDER BY InstallmentNo", conn);
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);

        var list = new List<OwnerInstallmentDetailResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var month = SafeStr(r, "Month");
            var dueDate = SafeStr(r, "DueDate");
            list.Add(new OwnerInstallmentDetailResponse
            {
                Id              = r.GetInt32(r.GetOrdinal("Id")),
                OwnerContractId = ownerContractId,
                InstallmentNo   = r.GetInt32(r.GetOrdinal("InstallmentNo")),
                Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
                PaidAmount      = r.GetDecimal(r.GetOrdinal("PaidAmount")),
                Balance         = r.GetDecimal(r.GetOrdinal("Balance")),
                DueDate         = dueDate,
                PaidDate        = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetString(r.GetOrdinal("PaidDate")),
                Status          = SafeStr(r, "Status"),
                PaymentMode     = SafeStr(r, "PaymentMode"),
                ReferenceNo     = SafeStr(r, "ReferenceNo"),
                Month           = month,
                MonthLabel      = string.IsNullOrEmpty(month) && !string.IsNullOrEmpty(dueDate)
                                    ? DateTime.Parse(dueDate).ToString("MMM yyyy")
                                    : month,
            });
        }
        return list;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET INSTALLMENT MONTHS
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<IEnumerable<OwnerInstallmentMonthResponse>> GetInstallmentMonthsAsync(int ownerContractId)
    {
        var installments = await GetInstallmentsAsync(ownerContractId);
        var months = installments
            .GroupBy(i => string.IsNullOrEmpty(i.Month) ? i.DueDate.Substring(0, 7) : i.Month)
            .Select(g =>
            {
                var first = g.First();
                var isFullyPaid = g.All(x => x.Status == "Paid" || x.Balance <= 0);
                return new OwnerInstallmentMonthResponse
                {
                    Month         = g.Key,
                    MonthLabel    = first.MonthLabel,
                    DueDate       = first.DueDate,
                    InstallmentNo = first.InstallmentNo,
                    IsFullyPaid   = isFullyPaid,
                };
            })
            .ToList();
        return months;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET LEDGER
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<IEnumerable<OwnerLedgerEntryResponse>> GetLedgerAsync(int ownerContractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Get contract total
        decimal contractTotal = 0;
        string ocCode = "";
        await using (var cmdOc = new SqlCommand("SELECT TotalAmount, OcCode FROM OwnerContracts WHERE Id=@Id AND ISNULL(IsDeleted,0)=0", conn))
        {
            cmdOc.Parameters.AddWithValue("@Id", ownerContractId);
            await using var rOc = await cmdOc.ExecuteReaderAsync();
            if (await rOc.ReadAsync()) { contractTotal = rOc.GetDecimal(0); ocCode = rOc.GetString(1); }
        }

        var ledger = new List<OwnerLedgerEntryResponse>();
        // Opening DR row
        ledger.Add(new OwnerLedgerEntryResponse
        {
            Date          = "",
            Description   = $"Owner Contract {ocCode} — Total Payable",
            InstallmentNos = null,
            Dr            = contractTotal,
            Cr            = 0,
            Balance       = contractTotal,
            Type          = "DR",
            TxnCode       = ocCode,
            TxnId         = null,
        });

        // CR rows from transactions
        await using var cmd = new SqlCommand(@"
            SELECT Id, TxnCode, CONVERT(VARCHAR(10),Date,120) AS Date,
                   ISNULL(Description,'') AS Description,
                   ISNULL(InstallmentNos,'') AS InstallmentNos,
                   Amount, ISNULL(Type,'CR') AS Type
            FROM OwnerTransactions
            WHERE OwnerContractId=@OwnerContractId
              AND Type IN ('CR','SD-PAY','SD-SETTLE')
              AND ISNULL(IsDeleted,0)=0
            ORDER BY Date, Id", conn);
        cmd.Parameters.AddWithValue("@OwnerContractId", ownerContractId);

        decimal runningBalance = contractTotal;
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var amt = r.GetDecimal(r.GetOrdinal("Amount"));
            runningBalance -= amt;
            ledger.Add(new OwnerLedgerEntryResponse
            {
                Date          = r.GetString(r.GetOrdinal("Date")),
                Description   = r.GetString(r.GetOrdinal("Description")),
                InstallmentNos = r.GetString(r.GetOrdinal("InstallmentNos")),
                Dr            = 0,
                Cr            = amt,
                Balance       = runningBalance,
                Type          = r.GetString(r.GetOrdinal("Type")),
                TxnCode       = r.GetString(r.GetOrdinal("TxnCode")),
                TxnId         = r.GetInt32(r.GetOrdinal("Id")),
            });
        }
        return ledger;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  UPDATE PAYMENT
    // ══════════════════════════════════════════════════════════════════════════
    public async Task<(bool Success, string TxnCode)> UpdatePaymentAsync(int txnId, UpdateOwnerPaymentRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Get existing transaction info
        decimal oldAmount = 0;
        int ownerContractId = 0;
        string oldInstallmentNos = "";
        string oldFundPoolCode = "";
        int? oldExpenseId = null;

        await using (var chkCmd = new SqlCommand(
            "SELECT Amount, OwnerContractId, ExpenseId, ISNULL(InstallmentNos,'') AS InstallmentNos FROM OwnerTransactions WHERE Id=@Id", conn))
        {
            chkCmd.Parameters.AddWithValue("@Id", txnId);
            await using var rChk = await chkCmd.ExecuteReaderAsync();
            if (!await rChk.ReadAsync()) return (false, "");
            oldAmount         = rChk.GetDecimal(0);
            ownerContractId   = rChk.GetInt32(1);
            oldExpenseId      = rChk.IsDBNull(2) ? null : rChk.GetInt32(2);
            oldInstallmentNos = rChk.GetString(3);
        }

        // Get new FundPool Code
        string newFundPoolCode = "";
        if (request.FundPoolId.HasValue)
        {
            await using var fpCmd = new SqlCommand("SELECT Code, Name FROM FundPools WHERE Id=@Id", conn);
            fpCmd.Parameters.AddWithValue("@Id", request.FundPoolId.Value);
            await using var rFp = await fpCmd.ExecuteReaderAsync();
            if (await rFp.ReadAsync()) { newFundPoolCode = rFp.GetString(0); request.FundPoolName = rFp.GetString(1); }
        }

        // Get old FundPool code from expense
        if (oldExpenseId.HasValue)
        {
            await using var epCmd = new SqlCommand("SELECT ISNULL(FundPool,'') FROM Expenses WHERE Id=@Id", conn);
            epCmd.Parameters.AddWithValue("@Id", oldExpenseId.Value);
            var epResult = await epCmd.ExecuteScalarAsync();
            oldFundPoolCode = epResult?.ToString() ?? "";
        }

        // Build new installmentNos
        var newInstallmentNos = request.InstallmentNos ?? "";
        if (request.MonthlyPayments != null && request.MonthlyPayments.Count > 0 && string.IsNullOrEmpty(newInstallmentNos))
            newInstallmentNos = string.Join(",", request.MonthlyPayments.Select(m => m.InstallmentNo));

        var sqlTxn = (Microsoft.Data.SqlClient.SqlTransaction)await conn.BeginTransactionAsync();
        try
        {
            // ── 1. REVERSE old monthly installments ─────────────────────────────
            if (!string.IsNullOrEmpty(oldInstallmentNos))
            {
                var oldNums = oldInstallmentNos.Split(',').Where(s => int.TryParse(s, out _)).Select(int.Parse).OrderBy(n => n);
                var revRemaining = oldAmount;
                foreach (var instNo in oldNums.Reverse())
                {
                    if (revRemaining <= 0) break;
                    decimal instPaid = 0;
                    await using (var balCmd = new SqlCommand(
                        "SELECT ISNULL(PaidAmount,0) FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn))
                    {
                        balCmd.Parameters.AddWithValue("@OcId", ownerContractId);
                        balCmd.Parameters.AddWithValue("@No", instNo);
                        var r = await balCmd.ExecuteScalarAsync();
                        instPaid = r != null && r != DBNull.Value ? (decimal)r : 0;
                    }
                    if (instPaid <= 0) continue;
                    var reverseAmt = Math.Min(revRemaining, instPaid);

                    await using var revCmd = new SqlCommand(@"
                        UPDATE OwnerMonthlyContractInstallments
                        SET PaidAmount = ISNULL(PaidAmount,0) - @Amt,
                            Balance = CASE WHEN Balance + @Amt > Amount THEN Amount ELSE Balance + @Amt END,
                            Status = CASE WHEN (ISNULL(PaidAmount,0)-@Amt) <= 0 THEN 'Pending' WHEN (ISNULL(PaidAmount,0)-@Amt)<Amount THEN 'Partial' ELSE 'Paid' END,
                            PaymentStatus = CASE WHEN (ISNULL(PaidAmount,0)-@Amt) <= 0 THEN 'Pending' WHEN (ISNULL(PaidAmount,0)-@Amt)<Amount THEN 'Partial' ELSE 'Paid' END,
                            PaidDate = CASE WHEN (ISNULL(PaidAmount,0)-@Amt) <= 0 THEN NULL ELSE PaidDate END,
                            UpdatedAt = GETDATE()
                        WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                    revCmd.Parameters.AddWithValue("@OcId", ownerContractId);
                    revCmd.Parameters.AddWithValue("@No", instNo);
                    revCmd.Parameters.AddWithValue("@Amt", reverseAmt);
                    await revCmd.ExecuteNonQueryAsync();
                    revRemaining -= reverseAmt;
                }

                // Also reverse OwnerInstallments — sequential from last paid (reverse order)
                var revRem2 = oldAmount;
                await using var revOiList = new SqlCommand(
                    "SELECT No, ISNULL(PaidAmount,0) AS PaidAmount FROM OwnerInstallments WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND ISNULL(PaidAmount,0)>0 ORDER BY No DESC", conn, sqlTxn);
                revOiList.Parameters.AddWithValue("@OcId", ownerContractId);
                var paidOiList = new List<(int No, decimal Paid)>();
                await using (var rRevOi = await revOiList.ExecuteReaderAsync())
                {
                    while (await rRevOi.ReadAsync())
                        paidOiList.Add((rRevOi.GetInt32(0), rRevOi.GetDecimal(1)));
                }

                foreach (var (instNo, oiPaid) in paidOiList)
                {
                    if (revRem2 <= 0) break;
                    if (oiPaid <= 0) continue;
                    var revAmt = Math.Min(revRem2, oiPaid);
                    await using var oiRevCmd = new SqlCommand(@"
                        UPDATE OwnerInstallments SET PaidAmount=ISNULL(PaidAmount,0)-@Amt,
                            Status=CASE WHEN (ISNULL(PaidAmount,0)-@Amt)<=0 THEN 'Pending' WHEN (ISNULL(PaidAmount,0)-@Amt)<Amount THEN 'Partial' ELSE 'Paid' END,
                            PaidDate=CASE WHEN (ISNULL(PaidAmount,0)-@Amt)<=0 THEN NULL ELSE PaidDate END
                        WHERE OwnerContractId=@OcId AND No=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                    oiRevCmd.Parameters.AddWithValue("@OcId", ownerContractId); oiRevCmd.Parameters.AddWithValue("@No", instNo); oiRevCmd.Parameters.AddWithValue("@Amt", revAmt);
                    await oiRevCmd.ExecuteNonQueryAsync();
                    revRem2 -= revAmt;
                }
            }

            // ── 2. APPLY new monthly payments ───────────────────────────────────
            if (request.MonthlyPayments != null && request.MonthlyPayments.Count > 0)
            {
                foreach (var mp in request.MonthlyPayments)
                {
                    if (mp.Amount <= 0) continue;
                    await using var updMci = new SqlCommand(@"
                        UPDATE OwnerMonthlyContractInstallments
                        SET PaidAmount = ISNULL(PaidAmount,0) + @Amt,
                            Balance = CASE WHEN Balance - @Amt < 0 THEN 0 ELSE Balance - @Amt END,
                            PaidDate = @PaidDate, PaymentMode = @PayMode,
                            Status = CASE WHEN (ISNULL(PaidAmount,0)+@Amt) >= Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END,
                            PaymentStatus = CASE WHEN (ISNULL(PaidAmount,0)+@Amt) >= Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END,
                            ReferenceNo = @RefNo, UpdatedAt = GETDATE()
                        WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                    updMci.Parameters.AddWithValue("@OcId", ownerContractId);
                    updMci.Parameters.AddWithValue("@No", mp.InstallmentNo);
                    updMci.Parameters.AddWithValue("@Amt", mp.Amount);
                    updMci.Parameters.AddWithValue("@PaidDate", request.PaidDate);
                    updMci.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                    updMci.Parameters.AddWithValue("@RefNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                    await updMci.ExecuteNonQueryAsync();
                }
            }
            else if (!string.IsNullOrEmpty(newInstallmentNos))
            {
                // Fallback: distribute sequentially
                var remaining = request.Amount;
                foreach (var instNo in newInstallmentNos.Split(',').Where(s => int.TryParse(s, out _)).Select(int.Parse).OrderBy(n => n))
                {
                    if (remaining <= 0) break;
                    decimal bal = 0;
                    await using (var bCmd = new SqlCommand("SELECT Balance FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn))
                    { bCmd.Parameters.AddWithValue("@OcId", ownerContractId); bCmd.Parameters.AddWithValue("@No", instNo); var v = await bCmd.ExecuteScalarAsync(); bal = v != null && v != DBNull.Value ? (decimal)v : 0; }
                    if (bal <= 0) continue;
                    var payThis = Math.Min(remaining, bal);
                    await using var uCmd = new SqlCommand(@"
                        UPDATE OwnerMonthlyContractInstallments SET PaidAmount=ISNULL(PaidAmount,0)+@Amt, Balance=CASE WHEN Balance-@Amt<0 THEN 0 ELSE Balance-@Amt END,
                            PaidDate=@PaidDate, PaymentMode=@PayMode, Status=CASE WHEN (ISNULL(PaidAmount,0)+@Amt)>=Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END,
                            PaymentStatus=CASE WHEN (ISNULL(PaidAmount,0)+@Amt)>=Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END, UpdatedAt=GETDATE()
                        WHERE OwnerContractId=@OcId AND InstallmentNo=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                    uCmd.Parameters.AddWithValue("@OcId", ownerContractId); uCmd.Parameters.AddWithValue("@No", instNo); uCmd.Parameters.AddWithValue("@Amt", payThis);
                    uCmd.Parameters.AddWithValue("@PaidDate", request.PaidDate); uCmd.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                    await uCmd.ExecuteNonQueryAsync();
                    remaining -= payThis;
                }
            }

            // Also update OwnerInstallments — sequential from first unpaid (same as Pay)
            {
                var rem2 = request.Amount;
                await using var oiListCmd = new SqlCommand(
                    "SELECT No, Amount, ISNULL(PaidAmount,0) AS PaidAmount FROM OwnerInstallments WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND (Amount - ISNULL(PaidAmount,0)) > 0 ORDER BY No", conn, sqlTxn);
                oiListCmd.Parameters.AddWithValue("@OcId", ownerContractId);
                var unpaidOi = new List<(int No, decimal Balance)>();
                await using (var rOi2 = await oiListCmd.ExecuteReaderAsync())
                {
                    while (await rOi2.ReadAsync())
                        unpaidOi.Add((rOi2.GetInt32(0), rOi2.GetDecimal(1) - rOi2.GetDecimal(2)));
                }

                foreach (var (instNo, oiBal) in unpaidOi)
                {
                    if (rem2 <= 0) break;
                    if (oiBal <= 0) continue;
                    var payThis = Math.Min(rem2, oiBal);
                    await using var oiCmd = new SqlCommand(@"
                        UPDATE OwnerInstallments SET PaidAmount=ISNULL(PaidAmount,0)+@Amt, PaidDate=@PaidDate, PaymentMode=@PayMode,
                            Status=CASE WHEN (ISNULL(PaidAmount,0)+@Amt)>=Amount THEN 'Paid' WHEN (ISNULL(PaidAmount,0)+@Amt)>0 THEN 'Partial' ELSE 'Pending' END
                        WHERE OwnerContractId=@OcId AND No=@No AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                    oiCmd.Parameters.AddWithValue("@OcId", ownerContractId);
                    oiCmd.Parameters.AddWithValue("@No", instNo);
                    oiCmd.Parameters.AddWithValue("@Amt", payThis);
                    oiCmd.Parameters.AddWithValue("@PaidDate", request.PaidDate);
                    oiCmd.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                    await oiCmd.ExecuteNonQueryAsync();
                    rem2 -= payThis;
                }
            }

            // ── 3. Update OwnerTransaction ──────────────────────────────────────
            await using (var updCmd = new SqlCommand(@"
                UPDATE OwnerTransactions SET Amount=@Amount, Date=@Date, PaymentMode=@PayMode,
                    ReferenceNo=@RefNo, Description=@Desc, InstallmentNos=@InstNos
                WHERE Id=@Id", conn, sqlTxn))
            {
                updCmd.Parameters.AddWithValue("@Id", txnId);
                updCmd.Parameters.AddWithValue("@Amount", request.Amount);
                updCmd.Parameters.AddWithValue("@Date", request.PaidDate);
                updCmd.Parameters.AddWithValue("@PayMode", request.PaymentMode ?? "Cash");
                updCmd.Parameters.AddWithValue("@RefNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                updCmd.Parameters.AddWithValue("@Desc", request.Notes ?? "");
                updCmd.Parameters.AddWithValue("@InstNos", newInstallmentNos);
                await updCmd.ExecuteNonQueryAsync();
            }

            // ── 4. FundPool: Restore old → Deduct new ──────────────────────────
            if (!string.IsNullOrEmpty(oldFundPoolCode))
            {
                await using var restFp = new SqlCommand("UPDATE FundPools SET Balance=Balance+@Amt, UpdatedAt=GETDATE() WHERE Code=@Code AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                restFp.Parameters.AddWithValue("@Amt", oldAmount); restFp.Parameters.AddWithValue("@Code", oldFundPoolCode);
                await restFp.ExecuteNonQueryAsync();
            }
            if (!string.IsNullOrEmpty(newFundPoolCode))
            {
                await using var newFp = new SqlCommand("UPDATE FundPools SET Balance=Balance-@Amt, UpdatedAt=GETDATE() WHERE Code=@Code AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                newFp.Parameters.AddWithValue("@Amt", request.Amount); newFp.Parameters.AddWithValue("@Code", newFundPoolCode);
                await newFp.ExecuteNonQueryAsync();
            }

            // ── 5. Update Expense ───────────────────────────────────────────────
            if (oldExpenseId.HasValue)
            {
                await using var updExp = new SqlCommand(@"
                    UPDATE Expenses SET Amount=@Amount, Date=@Date, Mode=@Mode, FundPool=@FPool, FundPoolName=@FPoolName, UpdatedAt=GETDATE() WHERE Id=@Id", conn, sqlTxn);
                updExp.Parameters.AddWithValue("@Id", oldExpenseId.Value);
                updExp.Parameters.AddWithValue("@Amount", request.Amount);
                updExp.Parameters.AddWithValue("@Date", request.PaidDate);
                updExp.Parameters.AddWithValue("@Mode", request.PaymentMode ?? "Cash");
                updExp.Parameters.AddWithValue("@FPool", newFundPoolCode);
                updExp.Parameters.AddWithValue("@FPoolName", request.FundPoolName ?? "");
                await updExp.ExecuteNonQueryAsync();
            }

            // ── 6. Update OwnerContracts timestamp ──────────────────────────────
            await using (var tsCmd = new SqlCommand("UPDATE OwnerContracts SET UpdatedAt=GETDATE() WHERE Id=@Id", conn, sqlTxn))
            { tsCmd.Parameters.AddWithValue("@Id", ownerContractId); await tsCmd.ExecuteNonQueryAsync(); }

            await sqlTxn.CommitAsync();

            // Get TxnCode
            await using var tcCmd = new SqlCommand("SELECT TxnCode FROM OwnerTransactions WHERE Id=@Id", conn);
            tcCmd.Parameters.AddWithValue("@Id", txnId);
            var tc = await tcCmd.ExecuteScalarAsync();
            return (true, tc?.ToString() ?? "");
        }
        catch (Exception ex)
        {
            await sqlTxn.RollbackAsync();
            Console.Error.WriteLine($"[OwnerPaymentRepo] UpdatePayment failed: {ex.Message}");
            return (false, "");
        }
    }
}
