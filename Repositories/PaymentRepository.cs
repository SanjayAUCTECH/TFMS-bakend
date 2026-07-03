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
        await using var cmd = new SqlCommand("SELECT * FROM Payments WHERE ContractId=@ContractId ORDER BY InstallmentNo", conn);
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
        return await cmd.ExecuteNonQueryAsync() > 0;
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
