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
            TotalPayable     = totalPayable,
            TotalPaidToOwner = totalPaid,
            BalanceDueToOwner = totalPayable - totalPaid,
            MonthlyRent      = r.IsDBNull(r.GetOrdinal("MonthlyRent")) ? 0 : r.GetDecimal(r.GetOrdinal("MonthlyRent")),
            NoOfMonths       = r.IsDBNull(r.GetOrdinal("NoOfMonths")) ? 0 : r.GetInt32(r.GetOrdinal("NoOfMonths")),
            TotalInstallments = r.IsDBNull(r.GetOrdinal("TotalInstallments")) ? 0 : r.GetInt32(r.GetOrdinal("TotalInstallments")),
            PaidCount        = r.IsDBNull(r.GetOrdinal("PaidCount")) ? 0 : r.GetInt32(r.GetOrdinal("PaidCount")),
            PendingCount     = r.IsDBNull(r.GetOrdinal("PendingCount")) ? 0 : r.GetInt32(r.GetOrdinal("PendingCount")),
            PartialCount     = r.IsDBNull(r.GetOrdinal("PartialCount")) ? 0 : r.GetInt32(r.GetOrdinal("PartialCount")),
            PaymentProgress  = totalPayable > 0 ? Math.Round(totalPaid / totalPayable * 100, 1) : 0,
            SecurityDeposit  = r.IsDBNull(r.GetOrdinal("SecurityDeposit")) ? 0 : r.GetDecimal(r.GetOrdinal("SecurityDeposit")),
            SecurityDepositPaid = r.IsDBNull(r.GetOrdinal("SecurityDepositPaid")) ? 0 : r.GetDecimal(r.GetOrdinal("SecurityDepositPaid")),
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
        await using var cmd = new SqlCommand("sp_PayOwner", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@OwnerContractId", request.OwnerContractId);
        cmd.Parameters.AddWithValue("@InstallmentNos",  request.InstallmentNos ?? "");
        cmd.Parameters.AddWithValue("@Amount",          request.Amount);
        cmd.Parameters.AddWithValue("@PaidDate",        request.PaidDate);
        cmd.Parameters.AddWithValue("@PaymentModeId",   (object?)request.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",     request.PaymentMode ?? "Cash");
        cmd.Parameters.AddWithValue("@ChequeNumber",    request.ChequeNumber ?? "");
        cmd.Parameters.AddWithValue("@ReferenceNo",     request.ReferenceNo ?? "");
        cmd.Parameters.AddWithValue("@FundPoolId",      (object?)request.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",    request.FundPoolName ?? "");
        cmd.Parameters.AddWithValue("@PaidBy",          request.PaidBy ?? "");
        cmd.Parameters.AddWithValue("@Notes",           request.Notes ?? "");
        cmd.Parameters.AddWithValue("@AddedBy",         (object?)request.AddedBy ?? DBNull.Value);

        var txnCodeParam = new SqlParameter("@TxnCode", SqlDbType.NVarChar, 50) { Direction = ParameterDirection.Output };
        var expenseIdParam = new SqlParameter("@ExpenseId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(txnCodeParam);
        cmd.Parameters.Add(expenseIdParam);

        try
        {
            await cmd.ExecuteNonQueryAsync();
            var txnCode = txnCodeParam.Value?.ToString() ?? "";
            var expenseId = expenseIdParam.Value != DBNull.Value ? (int?)expenseIdParam.Value : null;
            return (true, txnCode, expenseId);
        }
        catch (Exception ex)
        {
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
            WHERE t.Id = @TxnId", conn);
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
            WHERE t.Id = @TxnId", conn);
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

        // Get existing transaction
        decimal oldAmount = 0;
        int ownerContractId = 0;
        string oldFundPoolCode = "";
        int? oldExpenseId = null;

        await using (var chkCmd = new SqlCommand(
            "SELECT Amount, OwnerContractId, ExpenseId FROM OwnerTransactions WHERE Id=@Id", conn))
        {
            chkCmd.Parameters.AddWithValue("@Id", txnId);
            await using var rChk = await chkCmd.ExecuteReaderAsync();
            if (!await rChk.ReadAsync()) return (false, "");
            oldAmount         = rChk.GetDecimal(0);
            ownerContractId   = rChk.GetInt32(1);
            oldExpenseId      = rChk.IsDBNull(2) ? null : rChk.GetInt32(2);
        }

        // Get FundPool info
        string newFundPoolCode = "";
        if (request.FundPoolId.HasValue)
            await using (var fpCmd = new SqlCommand("SELECT Code, Name FROM FundPools WHERE Id=@Id", conn))
            {
                fpCmd.Parameters.AddWithValue("@Id", request.FundPoolId.Value);
                await using var rFp = await fpCmd.ExecuteReaderAsync();
                if (await rFp.ReadAsync()) { newFundPoolCode = rFp.GetString(0); request.FundPoolName = rFp.GetString(1); }
            }

        // Get old fund pool code from expense
        if (oldExpenseId.HasValue)
            await using (var epCmd = new SqlCommand("SELECT FundPool FROM Expenses WHERE Id=@Id", conn))
            {
                epCmd.Parameters.AddWithValue("@Id", oldExpenseId.Value);
                await using var rEp = await epCmd.ExecuteReaderAsync();
                if (await rEp.ReadAsync()) oldFundPoolCode = rEp.IsDBNull(0) ? "" : rEp.GetString(0);
            }

        var txnAmount = 0m; // placeholder, not used
        try
        {
            await using var sqlTxn = (Microsoft.Data.SqlClient.SqlTransaction)await conn.BeginTransactionAsync();

            // 1. Update OwnerTransaction
            await using (var updCmd = new SqlCommand(@"
                UPDATE OwnerTransactions
                SET Amount=@Amount, Date=@Date, PaymentMode=@PaymentMode,
                    ReferenceNo=@ReferenceNo, Description=@Desc, UpdatedAt=GETDATE()
                WHERE Id=@Id", conn, sqlTxn))
            {
                updCmd.Parameters.AddWithValue("@Id",          txnId);
                updCmd.Parameters.AddWithValue("@Amount",      request.Amount);
                updCmd.Parameters.AddWithValue("@Date",        request.PaidDate);
                updCmd.Parameters.AddWithValue("@PaymentMode", request.PaymentMode ?? "Cash");
                updCmd.Parameters.AddWithValue("@ReferenceNo", request.ChequeNumber ?? request.ReferenceNo ?? "");
                updCmd.Parameters.AddWithValue("@Desc",        request.Notes ?? "");
                await updCmd.ExecuteNonQueryAsync();
            }

            // 2. Reverse old installment amounts, apply new amounts
            if (!string.IsNullOrEmpty(request.InstallmentNos))
            {
                // Reset all installments for this contract that were in this transaction, then re-apply
                await using var resetCmd = new SqlCommand(@"
                    UPDATE OwnerMonthlyContractInstallments
                    SET PaidAmount = CASE WHEN ISNULL(PaidAmount,0) - @OldAmount < 0 THEN 0 ELSE ISNULL(PaidAmount,0) - @OldAmount END,
                        Balance = CASE WHEN Balance + @OldAmount > Amount THEN Amount ELSE Balance + @OldAmount END,
                        Status = CASE WHEN ISNULL(PaidAmount,0) - @OldAmount <= 0 THEN 'Pending' ELSE 'Partial' END,
                        UpdatedAt = GETDATE()
                    WHERE OwnerContractId=@OcId AND InstallmentNo IN (
                        SELECT CAST(value AS INT) FROM STRING_SPLIT(@InstNos,',') WHERE ISNUMERIC(value)=1
                    ) AND ISNULL(IsDeleted,0)=0", conn, sqlTxn);
                resetCmd.Parameters.AddWithValue("@OcId",     ownerContractId);
                resetCmd.Parameters.AddWithValue("@OldAmount", oldAmount);
                resetCmd.Parameters.AddWithValue("@InstNos",   request.InstallmentNos);
                await resetCmd.ExecuteNonQueryAsync();
            }

            // 3. Restore old fund pool balance
            if (!string.IsNullOrEmpty(oldFundPoolCode))
            {
                await using var restFp = new SqlCommand(
                    "UPDATE FundPools SET Balance=Balance+@Amt,UpdatedAt=GETDATE() WHERE Code=@Code AND ISNULL(IsDeleted,0)=0",
                    conn, sqlTxn);
                restFp.Parameters.AddWithValue("@Amt",  oldAmount);
                restFp.Parameters.AddWithValue("@Code", oldFundPoolCode);
                await restFp.ExecuteNonQueryAsync();
            }

            // 4. Deduct new fund pool balance
            if (!string.IsNullOrEmpty(newFundPoolCode))
            {
                await using var newFp = new SqlCommand(
                    "UPDATE FundPools SET Balance=Balance-@Amt,UpdatedAt=GETDATE() WHERE Code=@Code AND ISNULL(IsDeleted,0)=0",
                    conn, sqlTxn);
                newFp.Parameters.AddWithValue("@Amt",  request.Amount);
                newFp.Parameters.AddWithValue("@Code", newFundPoolCode);
                await newFp.ExecuteNonQueryAsync();
            }

            // 5. Update Expense record
            if (oldExpenseId.HasValue)
            {
                await using var updExp = new SqlCommand(@"
                    UPDATE Expenses
                    SET Amount=@Amount, Date=@Date, Mode=@Mode,
                        FundPool=@FPool, FundPoolName=@FPoolName, UpdatedAt=GETDATE()
                    WHERE Id=@Id", conn, sqlTxn);
                updExp.Parameters.AddWithValue("@Id",        oldExpenseId.Value);
                updExp.Parameters.AddWithValue("@Amount",    request.Amount);
                updExp.Parameters.AddWithValue("@Date",      request.PaidDate);
                updExp.Parameters.AddWithValue("@Mode",      request.PaymentMode ?? "Cash");
                updExp.Parameters.AddWithValue("@FPool",     newFundPoolCode);
                updExp.Parameters.AddWithValue("@FPoolName", request.FundPoolName ?? "");
                await updExp.ExecuteNonQueryAsync();
            }

            // 6. Update OwnerContracts timestamp
            await using (var tsCmd = new SqlCommand(
                "UPDATE OwnerContracts SET UpdatedAt=GETDATE() WHERE Id=@Id", conn, sqlTxn))
            {
                tsCmd.Parameters.AddWithValue("@Id", ownerContractId);
                await tsCmd.ExecuteNonQueryAsync();
            }

            await sqlTxn.CommitAsync();

            // Get TxnCode
            await using var tcCmd = new SqlCommand("SELECT TxnCode FROM OwnerTransactions WHERE Id=@Id", conn);
            tcCmd.Parameters.AddWithValue("@Id", txnId);
            var tc = await tcCmd.ExecuteScalarAsync();
            return (true, tc?.ToString() ?? "");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[OwnerPaymentRepo] UpdatePayment failed: {ex.Message}");
            return (false, "");
        }
    }
}
