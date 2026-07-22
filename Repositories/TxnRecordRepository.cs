using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class TxnRecordRepository : ITxnRecordRepository
{
    private readonly IDbConnectionFactory _factory;
    public TxnRecordRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<TxnRecord> Data, int Total)> GetAllAsync(TxnRecordListRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTxnRecords", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@ContractId", (object?)r.ContractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",   (object?)r.TenantId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)r.CampId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TxnType",    (object?)r.TxnType    ?? DBNull.Value);
        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);
        var list = new List<TxnRecord>();
        await using (var rd = await cmd.ExecuteReaderAsync())
            while (await rd.ReadAsync()) list.Add(Map(rd));
        return (list, (int)(totalParam.Value == DBNull.Value ? 0 : totalParam.Value));
    }

    public async Task<int> CreateAsync(TxnRecord t)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateTxnRecord", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TxnType",       t.TxnType);
        cmd.Parameters.AddWithValue("@ContractId",    t.ContractId);
        cmd.Parameters.AddWithValue("@ContractCode",  t.ContractCode);
        cmd.Parameters.AddWithValue("@TenantId",      t.TenantId);
        cmd.Parameters.AddWithValue("@CampId",        t.CampId);
        cmd.Parameters.AddWithValue("@TotalAmount",   t.TotalAmount);
        cmd.Parameters.AddWithValue("@Amount",        t.Amount);
        cmd.Parameters.AddWithValue("@TxnDate",       t.TxnDate);
        cmd.Parameters.AddWithValue("@FromDate",      (object?)t.FromDate    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",        (object?)t.ToDate      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",   t.PaymentMode    ?? "");
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)t.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolId",    (object?)t.FundPoolId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",  t.FundPoolName   ?? "");
        cmd.Parameters.AddWithValue("@Description",   t.Description    ?? "");
        cmd.Parameters.AddWithValue("@ReceivedBy",    t.ReceivedBy     ?? "");
        cmd.Parameters.AddWithValue("@ChequeNumber",  t.ChequeNumber   ?? "");
        cmd.Parameters.AddWithValue("@InstallmentNo", (object?)t.InstallmentNo ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(int id, UpdateTxnRecordRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // 1. Update TxnRecord
        await using var cmd = new SqlCommand("sp_UpdateTxnRecord", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",            id);
        cmd.Parameters.AddWithValue("@Amount",        r.Amount);
        cmd.Parameters.AddWithValue("@TxnDate",       r.TxnDate);
        cmd.Parameters.AddWithValue("@PaymentMode",   r.PaymentMode);
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)r.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolId",    (object?)r.FundPoolId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName",  r.FundPoolName);
        cmd.Parameters.AddWithValue("@Description",   r.Description);
        cmd.Parameters.AddWithValue("@ReceivedBy",    r.ReceivedBy);
        cmd.Parameters.AddWithValue("@ChequeNumber",  r.ChequeNumber);
        try { await cmd.ExecuteNonQueryAsync(); }
        catch { return false; }

        // 2. Handle room payments on edit
        if (r.RoomPayments != null && r.RoomPayments.Count > 0 && !string.IsNullOrEmpty(r.ContractId))
        {
            try
            {
                // Step A: Reverse old room amounts in ContractRooms + ContractRoomInstallments
                await using var reverseCmd = new SqlCommand(@"
                    UPDATE cr 
                    SET cr.PaidAmount = CASE WHEN ISNULL(cr.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cr.PaidAmount, 0) - crt.Amount END,
                        cr.Balance    = ISNULL(cr.TotalAmount, 0) - (CASE WHEN ISNULL(cr.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cr.PaidAmount, 0) - crt.Amount END)
                    FROM ContractRooms cr
                    INNER JOIN ContractRoomsTrns crt ON crt.ContractId = cr.ContractId AND crt.RoomId = cr.RoomId
                    WHERE crt.TxnType = 'CR' AND (
                        crt.TxnRecordId = @TxnRecordId 
                        OR (crt.TxnRecordId IS NULL AND crt.ContractId = @ContractId AND CONVERT(NVARCHAR(10), crt.TxnDate, 23) = @TxnDate)
                    )", conn);
                reverseCmd.Parameters.AddWithValue("@TxnRecordId", id);
                reverseCmd.Parameters.AddWithValue("@ContractId", r.ContractId);
                reverseCmd.Parameters.AddWithValue("@TxnDate", r.TxnDate.ToString("yyyy-MM-dd"));
                await reverseCmd.ExecuteNonQueryAsync();

                // Revert ContractRoomInstallments — SKIP here
                // CRI will be SET (not ADD) in Step C, so no need to revert separately
                // This avoids the bug where all installments of same room get reverted

                // Step B: Delete old ContractRoomsTrns entries
                await using var delCmd = new SqlCommand(@"
                    DELETE FROM ContractRoomsTrns WHERE TxnType = 'CR' AND (
                        TxnRecordId = @TxnRecordId 
                        OR (TxnRecordId IS NULL AND ContractId = @ContractId AND CONVERT(NVARCHAR(10), TxnDate, 23) = @TxnDate)
                    )", conn);
                delCmd.Parameters.AddWithValue("@TxnRecordId", id);
                delCmd.Parameters.AddWithValue("@ContractId", r.ContractId);
                delCmd.Parameters.AddWithValue("@TxnDate", r.TxnDate.ToString("yyyy-MM-dd"));
                await delCmd.ExecuteNonQueryAsync();

                // Step C: Insert new room entries + update ContractRooms with new amounts
                foreach (var room in r.RoomPayments)
                {
                    if (room.Amount <= 0) continue;

                    // Add new amount to ContractRooms
                    await using var updCmd = new SqlCommand(@"
                        UPDATE ContractRooms
                        SET PaidAmount = ISNULL(PaidAmount, 0) + @Amount,
                            Balance = ISNULL(TotalAmount, 0) - (ISNULL(PaidAmount, 0) + @Amount),
                            PaidDate = @PaidDate
                        WHERE ContractId = @ContractId AND RoomId = @RoomId", conn);
                    updCmd.Parameters.AddWithValue("@ContractId", r.ContractId);
                    updCmd.Parameters.AddWithValue("@RoomId", room.RoomId);
                    updCmd.Parameters.AddWithValue("@Amount", room.Amount);
                    updCmd.Parameters.AddWithValue("@PaidDate", r.TxnDate);
                    await updCmd.ExecuteNonQueryAsync();

                    // Insert new record in ContractRoomsTrns
                    await using var insCmd = new SqlCommand(@"
                        INSERT INTO ContractRoomsTrns (ContractId, RoomId, CampId, TxnType, TxnRecordId, TotalAmount, Amount, TxnDate, Month, Description, CreatedAt)
                        VALUES (@ContractId, @RoomId, @CampId, 'CR', @TxnRecordId, @Amount, @Amount, @TxnDate, @Month, @Description, GETDATE())", conn);
                    insCmd.Parameters.AddWithValue("@ContractId", r.ContractId);
                    insCmd.Parameters.AddWithValue("@RoomId", room.RoomId);
                    insCmd.Parameters.AddWithValue("@CampId", room.CampId);
                    insCmd.Parameters.AddWithValue("@TxnRecordId", id);
                    insCmd.Parameters.AddWithValue("@Amount", room.Amount);
                    insCmd.Parameters.AddWithValue("@TxnDate", r.TxnDate);
                    insCmd.Parameters.AddWithValue("@Month", room.Month ?? "");
                    insCmd.Parameters.AddWithValue("@Description", $"Payment updated - {r.PaymentMode} - {r.Description}");
                    await insCmd.ExecuteNonQueryAsync();

                    // ── Update ContractRoomInstallments — SET (not add) after revert ─
                    if (room.ContractRoomInstallmentId.HasValue && room.ContractRoomInstallmentId > 0)
                    {
                        await using var criCmd = new SqlCommand(@"
                            UPDATE ContractRoomInstallments
                            SET PaidAmount = @Amount,
                                Balance    = InstallAmount - @Amount,
                                PaidDate   = @PaidDate,
                                Status     = CASE
                                    WHEN @Amount >= InstallAmount THEN 'Paid'
                                    WHEN @Amount > 0 THEN 'Partial'
                                    ELSE 'Pending' END,
                                UpdatedAt  = GETDATE()
                            WHERE Id = @Id", conn);
                        criCmd.Parameters.AddWithValue("@Id",      room.ContractRoomInstallmentId.Value);
                        criCmd.Parameters.AddWithValue("@Amount",  room.Amount);
                        criCmd.Parameters.AddWithValue("@PaidDate", r.TxnDate);
                        await criCmd.ExecuteNonQueryAsync();
                    }
                    else if (room.InstallmentNo.HasValue)
                    {
                        await using var criCmd2 = new SqlCommand(@"
                            UPDATE ContractRoomInstallments
                            SET PaidAmount = @Amount,
                                Balance    = InstallAmount - @Amount,
                                PaidDate   = @PaidDate,
                                Status     = CASE
                                    WHEN @Amount >= InstallAmount THEN 'Paid'
                                    WHEN @Amount > 0 THEN 'Partial'
                                    ELSE 'Pending' END,
                                UpdatedAt  = GETDATE()
                            WHERE ContractId = @ContractId AND RoomId = @RoomId AND InstallmentNo = @InstNo", conn);
                        criCmd2.Parameters.AddWithValue("@ContractId", r.ContractId);
                        criCmd2.Parameters.AddWithValue("@RoomId",     room.RoomId);
                        criCmd2.Parameters.AddWithValue("@InstNo",     room.InstallmentNo.Value);
                        criCmd2.Parameters.AddWithValue("@Amount",     room.Amount);
                        criCmd2.Parameters.AddWithValue("@PaidDate",   r.TxnDate);
                        await criCmd2.ExecuteNonQueryAsync();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[TxnRecordRepo] Room update on edit failed: {ex.Message}");
            }
        }

        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteTxnRecord", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    private static TxnRecord Map(SqlDataReader r) => new()
    {
        Id                  = r.GetInt32(r.GetOrdinal("Id")),
        TxnId               = r.IsDBNull(r.GetOrdinal("TxnId"))               ? "" : r.GetString(r.GetOrdinal("TxnId")),
        TxnType             = r.IsDBNull(r.GetOrdinal("TxnType"))             ? "DR": r.GetString(r.GetOrdinal("TxnType")),
        ContractId          = r.IsDBNull(r.GetOrdinal("ContractId"))          ? "" : r.GetString(r.GetOrdinal("ContractId")),
        ContractCode        = r.IsDBNull(r.GetOrdinal("ContractCode"))        ? "" : r.GetString(r.GetOrdinal("ContractCode")),
        TenantId            = r.IsDBNull(r.GetOrdinal("TenantId"))            ? 0  : r.GetInt32(r.GetOrdinal("TenantId")),
        TenantName          = r.IsDBNull(r.GetOrdinal("TenantName"))          ? "" : r.GetString(r.GetOrdinal("TenantName")),
        CampId              = r.IsDBNull(r.GetOrdinal("CampId"))              ? 0  : r.GetInt32(r.GetOrdinal("CampId")),
        CampName            = r.IsDBNull(r.GetOrdinal("CampName"))            ? "" : r.GetString(r.GetOrdinal("CampName")),
        TotalAmount         = r.IsDBNull(r.GetOrdinal("TotalAmount"))         ? 0  : r.GetDecimal(r.GetOrdinal("TotalAmount")),
        Amount              = r.IsDBNull(r.GetOrdinal("Amount"))              ? 0  : r.GetDecimal(r.GetOrdinal("Amount")),
        TxnDate             = r.IsDBNull(r.GetOrdinal("TxnDate"))             ? DateTime.UtcNow : r.GetDateTime(r.GetOrdinal("TxnDate")),
        FromDate            = r.IsDBNull(r.GetOrdinal("FromDate"))            ? null : r.GetDateTime(r.GetOrdinal("FromDate")),
        ToDate              = r.IsDBNull(r.GetOrdinal("ToDate"))              ? null : r.GetDateTime(r.GetOrdinal("ToDate")),
        PaymentMode         = r.IsDBNull(r.GetOrdinal("PaymentMode"))         ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
        PaymentModeId       = r.IsDBNull(r.GetOrdinal("PaymentModeId"))       ? null : r.GetInt32(r.GetOrdinal("PaymentModeId")),
        ChequeNumber        = r.IsDBNull(r.GetOrdinal("ChequeNumber"))        ? "" : r.GetString(r.GetOrdinal("ChequeNumber")),
        FundPoolId          = r.IsDBNull(r.GetOrdinal("FundPoolId"))          ? null : r.GetInt32(r.GetOrdinal("FundPoolId")),
        FundPoolName        = r.IsDBNull(r.GetOrdinal("FundPoolName"))        ? "" : r.GetString(r.GetOrdinal("FundPoolName")),
        Description         = r.IsDBNull(r.GetOrdinal("Description"))         ? "" : r.GetString(r.GetOrdinal("Description")),
        ReceivedBy          = r.IsDBNull(r.GetOrdinal("ReceivedBy"))          ? "" : r.GetString(r.GetOrdinal("ReceivedBy")),
        ReceivedContact     = r.IsDBNull(r.GetOrdinal("ReceivedContact"))     ? "" : r.GetString(r.GetOrdinal("ReceivedContact")),
        IssuedBy            = r.IsDBNull(r.GetOrdinal("IssuedBy"))            ? "" : r.GetString(r.GetOrdinal("IssuedBy")),
        InstallmentNo       = r.IsDBNull(r.GetOrdinal("InstallmentNo"))       ? null : r.GetInt32(r.GetOrdinal("InstallmentNo")),
        AppliedInstallments = r.IsDBNull(r.GetOrdinal("AppliedInstallments")) ? "" : r.GetString(r.GetOrdinal("AppliedInstallments")),
        Unallocated         = r.IsDBNull(r.GetOrdinal("Unallocated"))         ? 0  : r.GetDecimal(r.GetOrdinal("Unallocated")),
        CreatedAt           = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt           = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
