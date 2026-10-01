using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class PaymentRepository : IPaymentRepository
{
    private readonly IDbConnectionFactory _factory;
    public PaymentRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Payment> Data, int TotalRecords)> GetAllAsync(PaymentListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPayments", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@ContractId",    (object?)request.ContractId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",      (object?)request.TenantId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",         (object?)request.Month         ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Year",          (object?)request.Year          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentStatus", (object?)request.PaymentStatus ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)request.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",      (object?)request.DateFrom      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",        (object?)request.DateTo        ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Payment>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Payment?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPaymentById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<IEnumerable<Payment>> GetByContractIdAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT * FROM ContractInstallments WHERE ContractId=@ContractId AND ISNULL(IsDeleted,0)=0 ORDER BY InstallmentNo", conn);
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        var list = new List<Payment>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    public async Task<bool> RecordPaymentAsync(Payment p)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_RecordPayment", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId",      p.ContractId);
        cmd.Parameters.AddWithValue("@InstallmentNo",   p.InstallmentNo);
        cmd.Parameters.AddWithValue("@PaidAmount",      p.PaidAmount);
        cmd.Parameters.AddWithValue("@PaidDate",        p.PaidDate ?? (object)DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentModeId",   p.PaymentModeId ?? (object)DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",     p.PaymentMode);
        cmd.Parameters.AddWithValue("@ChequeNumber",    p.ChequeNumber);
        cmd.Parameters.AddWithValue("@ClearanceDate",   p.ClearanceDate);
        cmd.Parameters.AddWithValue("@Description",     p.Description);
        cmd.Parameters.AddWithValue("@ReceivedBy",      p.ReceivedBy);
        cmd.Parameters.AddWithValue("@ReceivedContact", p.ReceivedContact);
        cmd.Parameters.AddWithValue("@FundPoolId",      p.FundPoolId ?? (object)DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",    p.FundPoolName);
        cmd.Parameters.AddWithValue("@IssuedBy",        p.IssuedBy);
        cmd.Parameters.AddWithValue("@AddedBy",         (object?)p.AddedBy ?? DBNull.Value);
        var txnIdOut = new SqlParameter("@NewTxnRecordId", System.Data.SqlDbType.Int)
            { Direction = System.Data.ParameterDirection.Output };
        cmd.Parameters.Add(txnIdOut);
        try {
            await cmd.ExecuteNonQueryAsync();
            return true;
        } catch {
            return false;
        }
    }

    public async Task<PaymentSummaryResponse?> GetSummaryAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPaymentSummary", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);

        PaymentSummaryResponse? summary = null;

        await using (var r = await cmd.ExecuteReaderAsync())
        {
            if (!await r.ReadAsync()) return null;
            var total = r.IsDBNull(r.GetOrdinal("ContractTotal")) ? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("ContractTotal")));
            var paid  = r.IsDBNull(r.GetOrdinal("TotalPaid"))     ? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalPaid")));
            summary = new PaymentSummaryResponse
            {
                ContractId        = r.GetString(r.GetOrdinal("ContractId")),
                TenantId          = r.GetInt32(r.GetOrdinal("TenantId")),
                TenantName        = r.IsDBNull(r.GetOrdinal("TenantName"))    ? "" : r.GetString(r.GetOrdinal("TenantName")),
                TenantContact     = r.IsDBNull(r.GetOrdinal("TenantContact")) ? "" : r.GetString(r.GetOrdinal("TenantContact")),
                CampId            = r.GetInt32(r.GetOrdinal("CampId")),
                CampName          = r.IsDBNull(r.GetOrdinal("CampName"))      ? "" : r.GetString(r.GetOrdinal("CampName")),
                StartDate         = r.IsDBNull(r.GetOrdinal("StartDate")) ? "" : r.GetString(r.GetOrdinal("StartDate")),
                EndDate           = r.IsDBNull(r.GetOrdinal("EndDate"))   ? "" : r.GetString(r.GetOrdinal("EndDate")),
                Months            = r.GetInt32(r.GetOrdinal("Months")),
                ContractTotal     = total,
                MonthlyTotal      = r.IsDBNull(r.GetOrdinal("MonthlyTotal"))     ? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("MonthlyTotal"))),
                LessorAmount      = r.IsDBNull(r.GetOrdinal("LessorAmount"))     ? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("LessorAmount"))),
                Status            = r.GetString(r.GetOrdinal("Status")),
                TotalInstallments = r.IsDBNull(r.GetOrdinal("TotalInstallments")) ? 0 : r.GetInt32(r.GetOrdinal("TotalInstallments")),
                PaidCount         = r.IsDBNull(r.GetOrdinal("PaidCount"))         ? 0 : r.GetInt32(r.GetOrdinal("PaidCount")),
                PendingCount      = r.IsDBNull(r.GetOrdinal("PendingCount"))      ? 0 : r.GetInt32(r.GetOrdinal("PendingCount")),
                PartialCount      = r.IsDBNull(r.GetOrdinal("PartialCount"))      ? 0 : r.GetInt32(r.GetOrdinal("PartialCount")),
                TotalPaid         = paid,
                TotalDue          = r.IsDBNull(r.GetOrdinal("TotalDue"))          ? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalDue"))),
                TotalScheduled    = r.IsDBNull(r.GetOrdinal("TotalScheduled"))    ? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalScheduled"))),
                NextInstallmentDue= r.IsDBNull(r.GetOrdinal("NextInstallmentDue"))? 0 : Convert.ToDecimal(r.GetValue(r.GetOrdinal("NextInstallmentDue"))),
                NextInstallmentNo = r.IsDBNull(r.GetOrdinal("NextInstallmentNo")) ? null : r.GetInt32(r.GetOrdinal("NextInstallmentNo")),
                RoomNos           = r.IsDBNull(r.GetOrdinal("RoomNos"))           ? "" : r.GetString(r.GetOrdinal("RoomNos")),
                RoomCount         = r.IsDBNull(r.GetOrdinal("RoomCount"))         ? 0  : r.GetInt32(r.GetOrdinal("RoomCount")),
                CollectionPct     = total > 0 ? Math.Round(paid / total * 100, 1) : 0,
            };
        }   // reader closed here

        // Load CampIds array from ContractCamps
        await using var campCmd = new SqlCommand(
            "SELECT CampId FROM ContractCamps WHERE ContractId = @ContractId ORDER BY Id", conn);
        campCmd.Parameters.AddWithValue("@ContractId", contractId);
        await using var campRdr = await campCmd.ExecuteReaderAsync();
        var campIds = new List<int>();
        while (await campRdr.ReadAsync()) campIds.Add(campRdr.GetInt32(0));
        summary.CampIds = campIds;

        return summary;
    }

    public async Task<IEnumerable<PaymentHistoryResponse>> GetHistoryAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPaymentHistory", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        var list = new List<PaymentHistoryResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new PaymentHistoryResponse
            {
                Id              = r.GetInt32(r.GetOrdinal("Id")),
                ContractId      = r.GetString(r.GetOrdinal("ContractId")),
                InstallmentNo   = r.GetInt32(r.GetOrdinal("InstallmentNo")),
                Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
                DueDate         = r.GetDateTime(r.GetOrdinal("DueDate")).ToString("yyyy-MM-dd"),
                PaidAmount      = r.GetDecimal(r.GetOrdinal("PaidAmount")),
                PaidDate        = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")).ToString("yyyy-MM-dd"),
                Status          = r.GetString(r.GetOrdinal("Status")),
                PaymentMode     = r.IsDBNull(r.GetOrdinal("PaymentMode"))     ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
                PaymentModeId   = r.IsDBNull(r.GetOrdinal("PaymentModeId"))   ? null : r.GetInt32(r.GetOrdinal("PaymentModeId")),
                ChequeNumber    = r.IsDBNull(r.GetOrdinal("ChequeNumber"))    ? "" : r.GetString(r.GetOrdinal("ChequeNumber")),
                ClearanceDate   = r.IsDBNull(r.GetOrdinal("ClearanceDate"))   ? "" : r.GetString(r.GetOrdinal("ClearanceDate")),
                Description     = r.IsDBNull(r.GetOrdinal("Description"))     ? "" : r.GetString(r.GetOrdinal("Description")),
                ReceivedBy      = r.IsDBNull(r.GetOrdinal("ReceivedBy"))      ? "" : r.GetString(r.GetOrdinal("ReceivedBy")),
                ReceivedContact = r.IsDBNull(r.GetOrdinal("ReceivedContact")) ? "" : r.GetString(r.GetOrdinal("ReceivedContact")),
                FundPoolId      = r.IsDBNull(r.GetOrdinal("FundPoolId"))      ? null : r.GetInt32(r.GetOrdinal("FundPoolId")),
                FundPoolName    = r.IsDBNull(r.GetOrdinal("FundPoolName"))    ? "" : r.GetString(r.GetOrdinal("FundPoolName")),
                IssuedBy        = r.IsDBNull(r.GetOrdinal("IssuedBy"))        ? "" : r.GetString(r.GetOrdinal("IssuedBy")),
                TenantName      = r.IsDBNull(r.GetOrdinal("TenantName"))      ? "" : r.GetString(r.GetOrdinal("TenantName")),
                CampName        = r.IsDBNull(r.GetOrdinal("CampName"))        ? "" : r.GetString(r.GetOrdinal("CampName")),
            });
        }
        return list;
    }

    private static Payment Map(SqlDataReader r) => new()
    {
        Id              = r.GetInt32(r.GetOrdinal("Id")),
        ContractId      = r.GetString(r.GetOrdinal("ContractId")),
        InstallmentNo   = r.GetInt32(r.GetOrdinal("InstallmentNo")),
        Amount          = r.GetDecimal(r.GetOrdinal("Amount")),
        DueDate         = r.GetDateTime(r.GetOrdinal("DueDate")),
        PaidAmount      = r.GetDecimal(r.GetOrdinal("PaidAmount")),
        PaidDate        = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")),
        Status          = r.GetString(r.GetOrdinal("Status")),
        PaymentMode     = r.IsDBNull(r.GetOrdinal("PaymentMode"))     ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
        ChequeNumber    = r.IsDBNull(r.GetOrdinal("ChequeNumber"))    ? "" : r.GetString(r.GetOrdinal("ChequeNumber")),
        ClearanceDate   = r.IsDBNull(r.GetOrdinal("ClearanceDate"))   ? "" : r.GetString(r.GetOrdinal("ClearanceDate")),
        Description     = r.IsDBNull(r.GetOrdinal("Description"))     ? "" : r.GetString(r.GetOrdinal("Description")),
        ReceivedBy      = r.IsDBNull(r.GetOrdinal("ReceivedBy"))      ? "" : r.GetString(r.GetOrdinal("ReceivedBy")),
        ReceivedContact = r.IsDBNull(r.GetOrdinal("ReceivedContact")) ? "" : r.GetString(r.GetOrdinal("ReceivedContact")),
        FundPoolId      = r.IsDBNull(r.GetOrdinal("FundPoolId"))      ? null : r.GetInt32(r.GetOrdinal("FundPoolId")),
        FundPoolName    = r.IsDBNull(r.GetOrdinal("FundPoolName"))    ? "" : r.GetString(r.GetOrdinal("FundPoolName")),
        IssuedBy        = r.IsDBNull(r.GetOrdinal("IssuedBy"))        ? "" : r.GetString(r.GetOrdinal("IssuedBy")),
        AddedBy         = r.IsDBNull(r.GetOrdinal("AddedBy"))         ? null : r.GetInt32(r.GetOrdinal("AddedBy")),
    };

    /// <summary>Soft-delete a payment installment (sets IsDeleted=1, DeletedBy)</summary>
    public async Task<bool> SoftDeleteAsync(int id, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "UPDATE ContractInstallments SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> RecordPaymentWithRoomsAsync(Payment p, string roomPaymentsJson)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var txn = (Microsoft.Data.SqlClient.SqlTransaction)await conn.BeginTransactionAsync();

        try
        {
            // ── 1. Call sp_RecordPayment (inside same transaction) ────────────
            await using var cmd = new SqlCommand("sp_RecordPayment", conn, txn)
            {
                CommandType = CommandType.StoredProcedure
            };
            cmd.Parameters.AddWithValue("@ContractId",      p.ContractId);
            cmd.Parameters.AddWithValue("@InstallmentNo",   p.InstallmentNo);
            cmd.Parameters.AddWithValue("@PaidAmount",      p.PaidAmount);
            cmd.Parameters.AddWithValue("@PaidDate",        p.PaidDate ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("@PaymentModeId",   p.PaymentModeId ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("@PaymentMode",     p.PaymentMode);
            cmd.Parameters.AddWithValue("@ChequeNumber",    p.ChequeNumber);
            cmd.Parameters.AddWithValue("@ClearanceDate",   p.ClearanceDate);
            cmd.Parameters.AddWithValue("@Description",     p.Description);
            cmd.Parameters.AddWithValue("@ReceivedBy",      p.ReceivedBy);
            cmd.Parameters.AddWithValue("@ReceivedContact", p.ReceivedContact);
            cmd.Parameters.AddWithValue("@FundPoolId",      p.FundPoolId ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("@FundPoolName",    p.FundPoolName);
            cmd.Parameters.AddWithValue("@IssuedBy",        p.IssuedBy);
            cmd.Parameters.AddWithValue("@AddedBy",         (object?)p.AddedBy ?? DBNull.Value);

            // ✅ Get TxnRecordId from SCOPE_IDENTITY via OUTPUT param (no race condition)
            var txnIdParam = new SqlParameter("@NewTxnRecordId", SqlDbType.Int) { Direction = ParameterDirection.Output };
            cmd.Parameters.Add(txnIdParam);

            await cmd.ExecuteNonQueryAsync();
            int txnRecordId = txnIdParam.Value != DBNull.Value ? (int)txnIdParam.Value : 0;

            // ── 2. Process each room payment ─────────────────────────────────
            if (!string.IsNullOrEmpty(roomPaymentsJson) && roomPaymentsJson != "[]")
            {
                var roomItems = System.Text.Json.JsonSerializer.Deserialize<List<DTOs.RoomPaymentItem>>(
                    roomPaymentsJson,
                    new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (roomItems != null)
                {
                    foreach (var room in roomItems)
                    {
                        if (room.Amount <= 0) continue;

                        // ── Update ContractRooms PaidAmount / Balance — cap to TotalAmount ─
                        await using var updCmd = new SqlCommand(@"
                            UPDATE ContractRooms
                            SET PaidAmount = CASE
                                    WHEN ISNULL(PaidAmount, 0) + @Amount > ISNULL(TotalAmount, 0) THEN ISNULL(TotalAmount, 0)
                                    ELSE ISNULL(PaidAmount, 0) + @Amount
                                END,
                                Balance    = CASE
                                    WHEN ISNULL(PaidAmount, 0) + @Amount >= ISNULL(TotalAmount, 0) THEN 0
                                    ELSE ISNULL(TotalAmount, 0) - (ISNULL(PaidAmount, 0) + @Amount)
                                END,
                                PaidDate   = @PaidDate
                            WHERE ContractId = @ContractId AND RoomId = @RoomId", conn, txn);
                        updCmd.Parameters.AddWithValue("@ContractId", p.ContractId);
                        updCmd.Parameters.AddWithValue("@RoomId",     room.RoomId);
                        updCmd.Parameters.AddWithValue("@Amount",     room.Amount);
                        updCmd.Parameters.AddWithValue("@PaidDate",   p.PaidDate ?? (object)DBNull.Value);
                        await updCmd.ExecuteNonQueryAsync();

                        // ── Insert into ContractRoomsTrns (with CriId + InstallmentNo for exact revert) ──
                        await using var insCmd = new SqlCommand(@"
                            INSERT INTO ContractRoomsTrns
                                (ContractId, RoomId, CampId, TxnType, TxnRecordId, TotalAmount, Amount, TxnDate, Month, Description, CriId, InstallmentNo, PaymentStatus, CreatedAt)
                            VALUES
                                (@ContractId, @RoomId, @CampId, 'CR', @TxnRecordId, @Amount, @Amount, @TxnDate, @Month, @Desc, @CriId, @InstallmentNo, @PaymentStatus, GETDATE())", conn, txn);
                        insCmd.Parameters.AddWithValue("@ContractId",  p.ContractId);
                        insCmd.Parameters.AddWithValue("@RoomId",      room.RoomId);
                        insCmd.Parameters.AddWithValue("@CampId",      room.CampId);
                        insCmd.Parameters.AddWithValue("@TxnRecordId", txnRecordId > 0 ? txnRecordId : (object)DBNull.Value);
                        insCmd.Parameters.AddWithValue("@Amount",      room.Amount);
                        insCmd.Parameters.AddWithValue("@TxnDate",     p.PaidDate ?? (object)DateTime.Today);
                        insCmd.Parameters.AddWithValue("@Month",       room.Month ?? "");
                        insCmd.Parameters.AddWithValue("@Desc",        $"Payment received - {p.PaymentMode}");
                        insCmd.Parameters.AddWithValue("@CriId",       room.ContractRoomInstallmentId.HasValue && room.ContractRoomInstallmentId > 0
                                                                            ? room.ContractRoomInstallmentId.Value : (object)DBNull.Value);
                        insCmd.Parameters.AddWithValue("@InstallmentNo", room.InstallmentNo.HasValue ? room.InstallmentNo.Value : (object)DBNull.Value);
                        insCmd.Parameters.AddWithValue("@PaymentStatus", string.IsNullOrEmpty(room.Status) ? (object)DBNull.Value : room.Status);
                        await insCmd.ExecuteNonQueryAsync();

                        // ── Update ContractRoomInstallments — Status ONLY from API ─
                        if (room.ContractRoomInstallmentId.HasValue && room.ContractRoomInstallmentId > 0)
                        {
                            await using var criCmd = new SqlCommand(@"
                                UPDATE ContractRoomInstallments
                                SET PaidAmount = CASE
                                        WHEN ISNULL(PaidAmount, 0) + @Amount > InstallAmount THEN InstallAmount
                                        ELSE ISNULL(PaidAmount, 0) + @Amount
                                    END,
                                    Balance    = CASE
                                        WHEN ISNULL(PaidAmount, 0) + @Amount >= InstallAmount THEN 0
                                        ELSE InstallAmount - (ISNULL(PaidAmount, 0) + @Amount)
                                    END,
                                    PaidDate   = @PaidDate,
                                    Status     = CASE WHEN @Status IS NOT NULL AND @Status <> '' THEN @Status ELSE Status END,
                                    UpdatedAt  = GETDATE()
                                WHERE Id = @Id", conn, txn);
                            criCmd.Parameters.AddWithValue("@Id",      room.ContractRoomInstallmentId.Value);
                            criCmd.Parameters.AddWithValue("@Amount",  room.Amount);
                            criCmd.Parameters.AddWithValue("@PaidDate", p.PaidDate ?? (object)DBNull.Value);
                            criCmd.Parameters.AddWithValue("@Status",  (object?)room.Status ?? DBNull.Value);
                            await criCmd.ExecuteNonQueryAsync();
                        }
                        else if (room.InstallmentNo.HasValue)
                        {
                            // Fallback: match by contractId + roomId + installmentNo
                            await using var criCmd2 = new SqlCommand(@"
                                UPDATE ContractRoomInstallments
                                SET PaidAmount = CASE
                                        WHEN ISNULL(PaidAmount, 0) + @Amount > InstallAmount THEN InstallAmount
                                        ELSE ISNULL(PaidAmount, 0) + @Amount
                                    END,
                                    Balance    = CASE
                                        WHEN ISNULL(PaidAmount, 0) + @Amount >= InstallAmount THEN 0
                                        ELSE InstallAmount - (ISNULL(PaidAmount, 0) + @Amount)
                                    END,
                                    PaidDate   = @PaidDate,
                                    Status     = CASE WHEN @Status IS NOT NULL AND @Status <> '' THEN @Status ELSE Status END,
                                    UpdatedAt  = GETDATE()
                                WHERE ContractId = @ContractId AND RoomId = @RoomId AND InstallmentNo = @InstNo", conn, txn);
                            criCmd2.Parameters.AddWithValue("@ContractId", p.ContractId);
                            criCmd2.Parameters.AddWithValue("@RoomId",     room.RoomId);
                            criCmd2.Parameters.AddWithValue("@InstNo",     room.InstallmentNo.Value);
                            criCmd2.Parameters.AddWithValue("@Amount",     room.Amount);
                            criCmd2.Parameters.AddWithValue("@PaidDate",   p.PaidDate ?? (object)DBNull.Value);
                            criCmd2.Parameters.AddWithValue("@Status",     (object?)room.Status ?? DBNull.Value);
                            await criCmd2.ExecuteNonQueryAsync();
                        }
                    }
                }
            }

            await txn.CommitAsync();
            return true;
        }
        catch (Exception ex)
        {
            await txn.RollbackAsync();
            Console.Error.WriteLine($"[PaymentRepo] RecordPaymentWithRooms failed: {ex.Message}");
            return false;
        }
    }

    public async Task<IEnumerable<ContractRoomPaymentInfo>> GetContractRoomsForPaymentAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Use direct SQL query (works without SP - fallback)
        var sql = @"
            SELECT
                cr.Id,
                cr.ContractId,
                cr.RoomId,
                ISNULL(cr.CampId, 0) AS CampId,
                ISNULL(r.RoomNo, '') AS RoomNo,
                ISNULL(ca.Name, '') AS CampName,
                ISNULL(cr.MonthlyAmount, r.MonthlyPrice) AS MonthlyAmount,
                ISNULL(cr.TotalAmount, 0) AS TotalAmount,
                ISNULL(cr.PaidAmount, 0) AS PaidAmount,
                ISNULL(cr.Balance, ISNULL(cr.TotalAmount, 0) - ISNULL(cr.PaidAmount, 0)) AS Balance
            FROM ContractRooms cr
            JOIN Rooms r ON r.Id = cr.RoomId
            LEFT JOIN Camps ca ON ca.Id = cr.CampId
            WHERE cr.ContractId = @ContractId
            ORDER BY ca.Name, r.RoomNo";

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        var list = new List<ContractRoomPaymentInfo>();
        await using var r2 = await cmd.ExecuteReaderAsync();
        while (await r2.ReadAsync())
        {
            list.Add(new ContractRoomPaymentInfo
            {
                Id            = r2.GetInt32(r2.GetOrdinal("Id")),
                ContractId    = contractId,
                RoomId        = r2.GetInt32(r2.GetOrdinal("RoomId")),
                CampId        = r2.IsDBNull(r2.GetOrdinal("CampId")) ? 0 : r2.GetInt32(r2.GetOrdinal("CampId")),
                RoomNo        = r2.IsDBNull(r2.GetOrdinal("RoomNo")) ? "" : r2.GetString(r2.GetOrdinal("RoomNo")),
                CampName      = r2.IsDBNull(r2.GetOrdinal("CampName")) ? "" : r2.GetString(r2.GetOrdinal("CampName")),
                MonthlyAmount = r2.IsDBNull(r2.GetOrdinal("MonthlyAmount")) ? 0 : r2.GetDecimal(r2.GetOrdinal("MonthlyAmount")),
                TotalAmount   = r2.IsDBNull(r2.GetOrdinal("TotalAmount")) ? 0 : r2.GetDecimal(r2.GetOrdinal("TotalAmount")),
                PaidAmount    = r2.IsDBNull(r2.GetOrdinal("PaidAmount")) ? 0 : r2.GetDecimal(r2.GetOrdinal("PaidAmount")),
                Balance       = r2.IsDBNull(r2.GetOrdinal("Balance")) ? 0 : r2.GetDecimal(r2.GetOrdinal("Balance")),
            });
        }
        return list;
    }

    public async Task<IEnumerable<RoomTransactionResponse>> GetRoomTransactionsAsync(string contractId, string? txnDate, int? txnRecordId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetRoomTransactions", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ContractId",  contractId);
        cmd.Parameters.AddWithValue("@TxnRecordId", txnRecordId.HasValue ? txnRecordId.Value : (object)DBNull.Value);
        cmd.Parameters.AddWithValue("@TxnDate",     !string.IsNullOrEmpty(txnDate) ? txnDate : (object)DBNull.Value);

        var list = new List<RoomTransactionResponse>();
        await using var r2 = await cmd.ExecuteReaderAsync();
        while (await r2.ReadAsync())
        {
            list.Add(new RoomTransactionResponse
            {
                Id          = r2.GetInt32(r2.GetOrdinal("Id")),
                ContractId  = contractId,
                RoomId      = r2.GetInt32(r2.GetOrdinal("RoomId")),
                CampId      = r2.IsDBNull(r2.GetOrdinal("CampId"))    ? 0  : r2.GetInt32(r2.GetOrdinal("CampId")),
                RoomNo      = r2.IsDBNull(r2.GetOrdinal("RoomNo"))     ? "" : r2.GetString(r2.GetOrdinal("RoomNo")),
                CampName    = r2.IsDBNull(r2.GetOrdinal("CampName"))   ? "" : r2.GetString(r2.GetOrdinal("CampName")),
                Amount      = r2.IsDBNull(r2.GetOrdinal("Amount"))     ? 0  : r2.GetDecimal(r2.GetOrdinal("Amount")),
                TxnDate     = r2.IsDBNull(r2.GetOrdinal("TxnDate"))    ? null : r2.GetString(r2.GetOrdinal("TxnDate")),
                TxnType     = r2.IsDBNull(r2.GetOrdinal("TxnType"))    ? null : r2.GetString(r2.GetOrdinal("TxnType")),
                Description = r2.IsDBNull(r2.GetOrdinal("Description"))? null : r2.GetString(r2.GetOrdinal("Description")),
                Month       = r2.IsDBNull(r2.GetOrdinal("Month"))      ? ""   : r2.GetString(r2.GetOrdinal("Month")),
            });
        }
        return list;
    }

    // ============================================
    // Bulk Payment Support Methods
    // ============================================

    /// <summary>
    /// Get filtered payment data from ContractRoomInstallments with complete contract details
    /// Only returns data for Active contracts
    /// </summary>
    public async Task<(IEnumerable<FilteredPaymentDataResponse> Data, int TotalRecords)> GetFilteredPaymentDataAsync(FilteredPaymentDataRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Build dynamic WHERE clause
        var whereConditions = new List<string> { "c.Status = 'Active'", "ISNULL(cri.IsDeleted, 0) = 0" };
        
        if (!string.IsNullOrEmpty(request.Month))
            whereConditions.Add("cri.Month = @Month");
        
        if (request.CampId.HasValue)
            whereConditions.Add("cri.CampId = @CampId");
        
        if (request.RoomId.HasValue)
            whereConditions.Add("cri.RoomId = @RoomId");
        
        if (!string.IsNullOrEmpty(request.Status))
            whereConditions.Add("cri.Status = @Status");
        
        if (!string.IsNullOrEmpty(request.ContractId))
            whereConditions.Add("cri.ContractId = @ContractId");
        
        if (request.TenantId.HasValue)
            whereConditions.Add("c.TenantId = @TenantId");
        
        var whereClause = string.Join(" AND ", whereConditions);

        // Build search filter
        var searchFilter = "";
        if (!string.IsNullOrEmpty(request.SearchText))
        {
            searchFilter = @" AND (
                c.ContractId LIKE @Search OR
                t.Name LIKE @Search OR
                t.EmiratesId LIKE @Search OR
                r.RoomNo LIKE @Search OR
                ca.Name LIKE @Search
            )";
        }

        // Main query with pagination
        var sql = $@"
            WITH FilteredData AS (
                SELECT 
                    -- ContractRoomInstallments columns
                    cri.Id,
                    cri.ContractId,
                    cri.RoomId,
                    cri.CampId,
                    cri.InstallmentNo,
                    cri.InstallAmount,
                    cri.DueDate,
                    cri.Month,
                    ISNULL(cri.PaymentMode, '') AS PaymentMode,
                    ISNULL(cri.ReferenceNo, '') AS ReferenceNo,
                    cri.ClearanceDate,
                    cri.Status,
                    ISNULL(cri.PaidAmount, 0) AS PaidAmount,
                    ISNULL(cri.Balance, cri.InstallAmount - ISNULL(cri.PaidAmount, 0)) AS Balance,
                    cri.PaidDate,
                    
                    -- Room details
                    r.RoomNo,
                    ISNULL(f.Name, '') AS FloorName,
                    
                    -- Camp details
                    ca.Name AS CampName,
                    ISNULL(ca.CampLocation, '') AS CampLocation,
                    
                    -- Contract details
                    c.StartDate AS ContractStartDate,
                    c.EndDate AS ContractEndDate,
                    c.Status AS ContractStatus,
                    c.Months AS ContractMonths,
                    c.ContractTotal AS ContractTotal,
                    ISNULL(c.MonthlyTotal, 0) AS MonthlyTotal,
                    
                    -- Tenant details
                    t.Id AS TenantId,
                    t.Name AS TenantName,
                    ISNULL(t.EmiratesId, '') AS TenantCode,
                    ISNULL(t.Contact, '') AS TenantContact,
                    ISNULL(t.Email, '') AS TenantEmail,
                    
                    -- Calculated fields
                    CASE 
                        WHEN cri.DueDate < GETDATE() AND cri.Status <> 'Paid' 
                        THEN DATEDIFF(DAY, cri.DueDate, GETDATE())
                        ELSE 0 
                    END AS DaysOverdue,
                    
                    CASE 
                        WHEN cri.DueDate < GETDATE() AND cri.Status <> 'Paid' 
                        THEN 1 
                        ELSE 0 
                    END AS IsOverdue

                FROM ContractRoomInstallments cri
                INNER JOIN Contracts c ON c.ContractId = cri.ContractId
                INNER JOIN Rooms r ON r.Id = cri.RoomId
                LEFT JOIN Floors f ON f.Id = r.FloorId
                INNER JOIN Camps ca ON ca.Id = cri.CampId
                INNER JOIN Tenants t ON t.Id = c.TenantId
                WHERE {whereClause} {searchFilter}
            ),
            TotalCount AS (
                SELECT COUNT(*) AS Total FROM FilteredData
            )
            SELECT 
                fd.*,
                tc.Total AS TotalRecords
            FROM FilteredData fd
            CROSS JOIN TotalCount tc
            ORDER BY 
                CASE WHEN @SortBy = 'dueDate' AND @SortDir = 'ASC' THEN fd.DueDate END ASC,
                CASE WHEN @SortBy = 'dueDate' AND @SortDir = 'DESC' THEN fd.DueDate END DESC,
                CASE WHEN @SortBy = 'amount' AND @SortDir = 'ASC' THEN fd.InstallAmount END ASC,
                CASE WHEN @SortBy = 'amount' AND @SortDir = 'DESC' THEN fd.InstallAmount END DESC,
                CASE WHEN @SortBy = 'status' AND @SortDir = 'ASC' THEN fd.Status END ASC,
                CASE WHEN @SortBy = 'status' AND @SortDir = 'DESC' THEN fd.Status END DESC,
                fd.DueDate ASC
            OFFSET @Offset ROWS
            FETCH NEXT @PageSize ROWS ONLY";

        await using var cmd = new SqlCommand(sql, conn);
        
        // Add parameters
        cmd.Parameters.AddWithValue("@Month", (object?)request.Month ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId", (object?)request.CampId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomId", (object?)request.RoomId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status", (object?)request.Status ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractId", (object?)request.ContractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId", (object?)request.TenantId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Search", string.IsNullOrEmpty(request.SearchText) ? DBNull.Value : $"%{request.SearchText}%");
        cmd.Parameters.AddWithValue("@SortBy", (object?)request.SortBy ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDir", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Offset", (request.ResolvedPageNumber - 1) * request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);

        var list = new List<FilteredPaymentDataResponse>();
        int totalRecords = 0;

        await using (var reader = await cmd.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                if (totalRecords == 0)
                {
                    totalRecords = reader.IsDBNull(reader.GetOrdinal("TotalRecords")) 
                        ? 0 
                        : reader.GetInt32(reader.GetOrdinal("TotalRecords"));
                }

                var item = new FilteredPaymentDataResponse
                {
                    // ContractRoomInstallments
                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                    ContractId = reader.GetString(reader.GetOrdinal("ContractId")),
                    RoomId = reader.GetInt32(reader.GetOrdinal("RoomId")),
                    CampId = reader.GetInt32(reader.GetOrdinal("CampId")),
                    InstallmentNo = reader.GetInt32(reader.GetOrdinal("InstallmentNo")),
                    InstallAmount = reader.GetDecimal(reader.GetOrdinal("InstallAmount")),
                    DueDate = reader.GetDateTime(reader.GetOrdinal("DueDate")),
                    Month = reader.GetString(reader.GetOrdinal("Month")),
                    PaymentMode = reader.GetString(reader.GetOrdinal("PaymentMode")),
                    ReferenceNo = reader.GetString(reader.GetOrdinal("ReferenceNo")),
                    ClearanceDate = reader.IsDBNull(reader.GetOrdinal("ClearanceDate")) 
                        ? null 
                        : reader.GetDateTime(reader.GetOrdinal("ClearanceDate")),
                    Status = reader.GetString(reader.GetOrdinal("Status")),
                    PaidAmount = reader.GetDecimal(reader.GetOrdinal("PaidAmount")),
                    Balance = reader.GetDecimal(reader.GetOrdinal("Balance")),
                    PaidDate = reader.IsDBNull(reader.GetOrdinal("PaidDate")) 
                        ? null 
                        : reader.GetDateTime(reader.GetOrdinal("PaidDate")),
                    
                    // Room
                    RoomNo = reader.GetString(reader.GetOrdinal("RoomNo")),
                    FloorName = reader.GetString(reader.GetOrdinal("FloorName")),
                    
                    // Camp
                    CampName = reader.GetString(reader.GetOrdinal("CampName")),
                    CampLocation = reader.GetString(reader.GetOrdinal("CampLocation")),
                    
                    // Contract
                    ContractStartDate = reader.GetDateTime(reader.GetOrdinal("ContractStartDate")),
                    ContractEndDate = reader.GetDateTime(reader.GetOrdinal("ContractEndDate")),
                    ContractStatus = reader.GetString(reader.GetOrdinal("ContractStatus")),
                    ContractMonths = reader.GetInt32(reader.GetOrdinal("ContractMonths")),
                    ContractTotal = reader.GetDecimal(reader.GetOrdinal("ContractTotal")),
                    MonthlyTotal = reader.GetDecimal(reader.GetOrdinal("MonthlyTotal")),
                    
                    // Tenant
                    TenantId = reader.GetInt32(reader.GetOrdinal("TenantId")),
                    TenantName = reader.GetString(reader.GetOrdinal("TenantName")),
                    TenantCode = reader.GetString(reader.GetOrdinal("TenantCode")),
                    TenantContact = reader.GetString(reader.GetOrdinal("TenantContact")),
                    TenantEmail = reader.GetString(reader.GetOrdinal("TenantEmail")),
                    
                    // Calculated
                    DaysOverdue = reader.GetInt32(reader.GetOrdinal("DaysOverdue")),
                    IsOverdue = reader.GetInt32(reader.GetOrdinal("IsOverdue")) == 1
                };

                list.Add(item);
            }
        } // Reader is now closed

        // Get Contract Installments Summary for each contract
        if (list.Count > 0)
        {
            var contractIds = list.Select(x => x.ContractId).Distinct().ToList();
            var summaryQuery = @"
                SELECT 
                    ContractId,
                    SUM(Amount) AS TotalDueAmount,
                    SUM(PaidAmount) AS TotalPaidAmount,
                    SUM(Amount - PaidAmount) AS TotalBalance
                FROM ContractInstallments
                WHERE ContractId IN (" + string.Join(",", contractIds.Select((_, i) => $"@ContractId{i}")) + @")
                  AND ISNULL(IsDeleted, 0) = 0
                GROUP BY ContractId";

            await using var summaryCmd = new SqlCommand(summaryQuery, conn);
            for (int i = 0; i < contractIds.Count; i++)
            {
                summaryCmd.Parameters.AddWithValue($"@ContractId{i}", contractIds[i]);
            }

            var summaryDict = new Dictionary<string, (decimal TotalDue, decimal TotalPaid, decimal TotalBalance)>();
            await using (var summaryReader = await summaryCmd.ExecuteReaderAsync())
            {
                while (await summaryReader.ReadAsync())
                {
                    var contractId = summaryReader.GetString(0);
                    summaryDict[contractId] = (
                        summaryReader.GetDecimal(1),
                        summaryReader.GetDecimal(2),
                        summaryReader.GetDecimal(3)
                    );
                }
            } // Summary reader is now closed

            // Assign summary to items
            foreach (var item in list)
            {
                if (summaryDict.TryGetValue(item.ContractId, out var summary))
                {
                    item.TotalDueAmount = summary.TotalDue;
                    item.TotalPaidAmount = summary.TotalPaid;
                    item.TotalBalance = summary.TotalBalance;
                }
            }
        }

        return (list, totalRecords);
    }
}
