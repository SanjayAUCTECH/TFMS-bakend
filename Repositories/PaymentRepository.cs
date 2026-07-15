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
        await using var cmd = new SqlCommand("SELECT * FROM ContractInstallments WHERE ContractId=@ContractId ORDER BY InstallmentNo", conn);
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
        // SP uses SET NOCOUNT ON — ExecuteNonQuery returns -1, use try/catch instead
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
    };
}
