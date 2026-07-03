using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class ReportRepository : IReportRepository
{
    private readonly IDbConnectionFactory _factory;
    public ReportRepository(IDbConnectionFactory factory) => _factory = factory;

    // ── Inventory Report ──────────────────────────────────────────────────────
    public async Task<(IEnumerable<InventoryReportRow> Data, int Total)> GetInventoryReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetInventoryReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",  r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",    r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",      (object?)r.CampId     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<InventoryReportRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new InventoryReportRow
        {
            RoomId         = rd.GetInt32(rd.GetOrdinal("RoomId")),
            RoomNo         = rd.GetString(rd.GetOrdinal("RoomNo")),
            CampName       = rd.IsDBNull(rd.GetOrdinal("CampName"))       ? "" : rd.GetString(rd.GetOrdinal("CampName")),
            FloorName      = rd.IsDBNull(rd.GetOrdinal("FloorName"))      ? "" : rd.GetString(rd.GetOrdinal("FloorName")),
            Status         = rd.GetString(rd.GetOrdinal("Status")),
            Occupied       = rd.GetBoolean(rd.GetOrdinal("Occupied")),
            MonthlyPrice   = rd.GetDecimal(rd.GetOrdinal("MonthlyPrice")),
            TenantName     = rd.IsDBNull(rd.GetOrdinal("TenantName"))     ? "" : rd.GetString(rd.GetOrdinal("TenantName")),
            ContractId     = rd.IsDBNull(rd.GetOrdinal("ContractId"))     ? "" : rd.GetString(rd.GetOrdinal("ContractId")),
            ContractStatus = rd.IsDBNull(rd.GetOrdinal("ContractStatus")) ? "" : rd.GetString(rd.GetOrdinal("ContractStatus")),
            OtherDetails   = rd.IsDBNull(rd.GetOrdinal("OtherDetails"))   ? "" : rd.GetString(rd.GetOrdinal("OtherDetails")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    // ── Tenant Report ─────────────────────────────────────────────────────────
    public async Task<(IEnumerable<TenantReportRow> Data, int Total)> GetTenantReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTenantReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)r.CampId     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<TenantReportRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new TenantReportRow
        {
            TenantId       = rd.GetInt32(rd.GetOrdinal("TenantId")),
            TenantName     = rd.GetString(rd.GetOrdinal("TenantName")),
            Contact        = rd.IsDBNull(rd.GetOrdinal("Contact"))        ? "" : rd.GetString(rd.GetOrdinal("Contact")),
            Email          = rd.IsDBNull(rd.GetOrdinal("Email"))          ? "" : rd.GetString(rd.GetOrdinal("Email")),
            EmiratesId     = rd.IsDBNull(rd.GetOrdinal("EmiratesId"))     ? "" : rd.GetString(rd.GetOrdinal("EmiratesId")),
            Nationality    = rd.IsDBNull(rd.GetOrdinal("Nationality"))    ? "" : rd.GetString(rd.GetOrdinal("Nationality")),
            Status         = rd.GetString(rd.GetOrdinal("Status")),
            ContractId     = rd.IsDBNull(rd.GetOrdinal("ContractId"))     ? "" : rd.GetString(rd.GetOrdinal("ContractId")),
            CampName       = rd.IsDBNull(rd.GetOrdinal("CampName"))       ? "" : rd.GetString(rd.GetOrdinal("CampName")),
            RoomNo         = rd.IsDBNull(rd.GetOrdinal("RoomNo"))         ? "" : rd.GetString(rd.GetOrdinal("RoomNo")),
            ContractStart  = rd.IsDBNull(rd.GetOrdinal("ContractStart"))  ? null : rd.GetDateTime(rd.GetOrdinal("ContractStart")),
            ContractEnd    = rd.IsDBNull(rd.GetOrdinal("ContractEnd"))    ? null : rd.GetDateTime(rd.GetOrdinal("ContractEnd")),
            ContractStatus = rd.IsDBNull(rd.GetOrdinal("ContractStatus")) ? "" : rd.GetString(rd.GetOrdinal("ContractStatus")),
            MonthlyRent    = rd.IsDBNull(rd.GetOrdinal("MonthlyRent"))    ? 0 : rd.GetDecimal(rd.GetOrdinal("MonthlyRent")),
            TotalPaid      = rd.IsDBNull(rd.GetOrdinal("TotalPaid"))      ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalPaid")),
            TotalDue       = rd.IsDBNull(rd.GetOrdinal("TotalDue"))       ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalDue")),
            Balance        = rd.IsDBNull(rd.GetOrdinal("Balance"))        ? 0 : rd.GetDecimal(rd.GetOrdinal("Balance")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    // ── Partner Report ────────────────────────────────────────────────────────
    public async Task<(IEnumerable<PartnerReportRow> Data, int Total)> GetPartnerReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetPartnerReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<PartnerReportRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new PartnerReportRow
        {
            PartnerId   = rd.GetInt32(rd.GetOrdinal("PartnerId")),
            PartnerCode = rd.GetString(rd.GetOrdinal("PartnerCode")),
            PartnerName = rd.GetString(rd.GetOrdinal("PartnerName")),
            Contact     = rd.IsDBNull(rd.GetOrdinal("Contact"))   ? "" : rd.GetString(rd.GetOrdinal("Contact")),
            Mobile      = rd.IsDBNull(rd.GetOrdinal("Mobile"))    ? "" : rd.GetString(rd.GetOrdinal("Mobile")),
            Status      = rd.GetString(rd.GetOrdinal("Status")),
            TotalCamps  = rd.IsDBNull(rd.GetOrdinal("TotalCamps")) ? 0 : rd.GetInt32(rd.GetOrdinal("TotalCamps")),
            CampNames   = rd.IsDBNull(rd.GetOrdinal("CampNames"))  ? "" : rd.GetString(rd.GetOrdinal("CampNames")),
            ShareValue  = rd.IsDBNull(rd.GetOrdinal("ShareValue")) ? 0 : rd.GetDecimal(rd.GetOrdinal("ShareValue")),
            ShareType   = rd.IsDBNull(rd.GetOrdinal("ShareType"))  ? "" : rd.GetString(rd.GetOrdinal("ShareType")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    // ── Camp Report ───────────────────────────────────────────────────────────
    public async Task<(IEnumerable<CampReportRow> Data, int Total)> GetCampReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetCampReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<CampReportRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new CampReportRow
        {
            CampId            = rd.GetInt32(rd.GetOrdinal("CampId")),
            CampCode          = rd.GetString(rd.GetOrdinal("CampCode")),
            CampName          = rd.GetString(rd.GetOrdinal("CampName")),
            Status            = rd.GetString(rd.GetOrdinal("Status")),
            TotalRooms        = rd.IsDBNull(rd.GetOrdinal("TotalRooms"))        ? 0 : rd.GetInt32(rd.GetOrdinal("TotalRooms")),
            OccupiedRooms     = rd.IsDBNull(rd.GetOrdinal("OccupiedRooms"))     ? 0 : rd.GetInt32(rd.GetOrdinal("OccupiedRooms")),
            VacantRooms       = rd.IsDBNull(rd.GetOrdinal("VacantRooms"))       ? 0 : rd.GetInt32(rd.GetOrdinal("VacantRooms")),
            ActiveContracts   = rd.IsDBNull(rd.GetOrdinal("ActiveContracts"))   ? 0 : rd.GetInt32(rd.GetOrdinal("ActiveContracts")),
            TotalMonthlyRent  = rd.IsDBNull(rd.GetOrdinal("TotalMonthlyRent"))  ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalMonthlyRent")),
            TotalCollected    = rd.IsDBNull(rd.GetOrdinal("TotalCollected"))    ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalCollected")),
            TotalDue          = rd.IsDBNull(rd.GetOrdinal("TotalDue"))          ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalDue")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    // ── Waiver Report ─────────────────────────────────────────────────────────
    public async Task<(IEnumerable<WaiverReportRow> Data, int Total)> GetWaiverReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetWaiverReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",   (object?)r.TenantId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)r.DateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)r.DateTo     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<WaiverReportRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new WaiverReportRow
        {
            WaiverId       = rd.GetInt32(rd.GetOrdinal("WaiverId")),
            TenantId       = rd.GetInt32(rd.GetOrdinal("TenantId")),
            TenantName     = rd.GetString(rd.GetOrdinal("TenantName")),
            ContractId     = rd.GetString(rd.GetOrdinal("ContractId")),
            InstallmentNo  = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
            OriginalAmount = rd.GetDecimal(rd.GetOrdinal("OriginalAmount")),
            WaiverAmount   = rd.GetDecimal(rd.GetOrdinal("WaiverAmount")),
            BalanceAmount  = rd.GetDecimal(rd.GetOrdinal("BalanceAmount")),
            Remark         = rd.IsDBNull(rd.GetOrdinal("Remark")) ? "" : rd.GetString(rd.GetOrdinal("Remark")),
            WaiverDate     = rd.GetDateTime(rd.GetOrdinal("WaiverDate")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    // ── Tenant Ledger ─────────────────────────────────────────────────────────
    public async Task<TenantLedgerSummary?> GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTenantLedger", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TenantId",   tenantId);
        cmd.Parameters.AddWithValue("@ContractId", (object?)contractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)dateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)dateTo     ?? DBNull.Value);
        await using var rd = await cmd.ExecuteReaderAsync();

        // First result set: summary
        if (!await rd.ReadAsync()) return null;
        var summary = new TenantLedgerSummary
        {
            TenantName  = rd.IsDBNull(rd.GetOrdinal("TenantName"))  ? "" : rd.GetString(rd.GetOrdinal("TenantName")),
            Contact     = rd.IsDBNull(rd.GetOrdinal("Contact"))     ? "" : rd.GetString(rd.GetOrdinal("Contact")),
            TotalDebit  = rd.IsDBNull(rd.GetOrdinal("TotalDebit"))  ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalDebit")),
            TotalCredit = rd.IsDBNull(rd.GetOrdinal("TotalCredit")) ? 0 : rd.GetDecimal(rd.GetOrdinal("TotalCredit")),
            NetBalance  = rd.IsDBNull(rd.GetOrdinal("NetBalance"))  ? 0 : rd.GetDecimal(rd.GetOrdinal("NetBalance")),
        };

        // Second result set: rows
        await rd.NextResultAsync();
        int serial = 0;
        while (await rd.ReadAsync())
        {
            summary.Rows.Add(new TenantLedgerRow
            {
                SerialNo      = ++serial,
                Date          = rd.GetDateTime(rd.GetOrdinal("Date")),
                Description   = rd.IsDBNull(rd.GetOrdinal("Description"))   ? "" : rd.GetString(rd.GetOrdinal("Description")),
                Type          = rd.IsDBNull(rd.GetOrdinal("Type"))          ? "" : rd.GetString(rd.GetOrdinal("Type")),
                Debit         = rd.IsDBNull(rd.GetOrdinal("Debit"))         ? 0 : rd.GetDecimal(rd.GetOrdinal("Debit")),
                Credit        = rd.IsDBNull(rd.GetOrdinal("Credit"))        ? 0 : rd.GetDecimal(rd.GetOrdinal("Credit")),
                Balance       = rd.IsDBNull(rd.GetOrdinal("Balance"))       ? 0 : rd.GetDecimal(rd.GetOrdinal("Balance")),
                ContractId    = rd.IsDBNull(rd.GetOrdinal("ContractId"))    ? "" : rd.GetString(rd.GetOrdinal("ContractId")),
                InstallmentNo = rd.IsDBNull(rd.GetOrdinal("InstallmentNo")) ? 0 : rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                PaymentMode   = rd.IsDBNull(rd.GetOrdinal("PaymentMode"))   ? "" : rd.GetString(rd.GetOrdinal("PaymentMode")),
                Reference     = rd.IsDBNull(rd.GetOrdinal("Reference"))     ? "" : rd.GetString(rd.GetOrdinal("Reference")),
            });
        }
        return summary;
    }

    // ── Transaction Statement ─────────────────────────────────────────────────
    public async Task<(IEnumerable<TransactionRow> Data, int Total)> GetTransactionStatementAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTransactionStatement", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",  r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",    r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)r.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractId",  (object?)r.ContractId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",    (object?)r.TenantId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",      (object?)r.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      (object?)r.Status      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",    (object?)r.DateFrom    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",      (object?)r.DateTo      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",       (object?)r.Month       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Year",        (object?)r.Year        ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<TransactionRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new TransactionRow
        {
            Id            = rd.GetInt32(rd.GetOrdinal("Id")),
            Date          = rd.GetDateTime(rd.GetOrdinal("Date")),
            ContractId    = rd.GetString(rd.GetOrdinal("ContractId")),
            TenantName    = rd.IsDBNull(rd.GetOrdinal("TenantName"))    ? "" : rd.GetString(rd.GetOrdinal("TenantName")),
            CampName      = rd.IsDBNull(rd.GetOrdinal("CampName"))      ? "" : rd.GetString(rd.GetOrdinal("CampName")),
            RoomNo        = rd.IsDBNull(rd.GetOrdinal("RoomNo"))        ? "" : rd.GetString(rd.GetOrdinal("RoomNo")),
            InstallmentNo = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
            Amount        = rd.GetDecimal(rd.GetOrdinal("Amount")),
            PaidAmount    = rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
            Balance       = rd.GetDecimal(rd.GetOrdinal("Balance")),
            PaymentMode   = rd.IsDBNull(rd.GetOrdinal("PaymentMode"))   ? "" : rd.GetString(rd.GetOrdinal("PaymentMode")),
            Status        = rd.GetString(rd.GetOrdinal("Status")),
            ReceivedBy    = rd.IsDBNull(rd.GetOrdinal("ReceivedBy"))    ? "" : rd.GetString(rd.GetOrdinal("ReceivedBy")),
            FundPoolName  = rd.IsDBNull(rd.GetOrdinal("FundPoolName"))  ? "" : rd.GetString(rd.GetOrdinal("FundPoolName")),
            ChequeNumber  = rd.IsDBNull(rd.GetOrdinal("ChequeNumber"))  ? "" : rd.GetString(rd.GetOrdinal("ChequeNumber")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    // ── Room History ──────────────────────────────────────────────────────────
    public async Task<IEnumerable<RoomHistoryRow>> GetRoomHistoryAsync(int roomId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetRoomHistory", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@RoomId", roomId);
        var list = new List<RoomHistoryRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new RoomHistoryRow
        {
            ContractId  = rd.GetString(rd.GetOrdinal("ContractId")),
            TenantName  = rd.GetString(rd.GetOrdinal("TenantName")),
            StartDate   = rd.GetDateTime(rd.GetOrdinal("StartDate")),
            EndDate     = rd.GetDateTime(rd.GetOrdinal("EndDate")),
            MonthlyRent = rd.GetDecimal(rd.GetOrdinal("MonthlyRent")),
            Status      = rd.GetString(rd.GetOrdinal("Status")),
        });
        return list;
    }

    // ── Make Payment (outgoing) ───────────────────────────────────────────────
    public async Task<int> MakePaymentAsync(MakePaymentRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_MakePayment", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PaymentType",   request.PaymentType);
        cmd.Parameters.AddWithValue("@RecipientId",   (object?)request.RecipientId   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientName", request.RecipientName);
        cmd.Parameters.AddWithValue("@Amount",        request.Amount);
        cmd.Parameters.AddWithValue("@PaymentDate",   request.PaymentDate);
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)request.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaymentMode",   request.PaymentMode);
        cmd.Parameters.AddWithValue("@Description",   request.Description);
        cmd.Parameters.AddWithValue("@FundPoolId",    (object?)request.FundPoolId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Reference",     request.Reference);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AccountHeadId", (object?)request.AccountHeadId ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<(IEnumerable<MakePaymentResponse> Data, int Total)> GetOutgoingPaymentsAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOutgoingPayments", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",   (object?)r.DateFrom   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",     (object?)r.DateTo     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<MakePaymentResponse>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new MakePaymentResponse
        {
            Id            = rd.GetInt32(rd.GetOrdinal("Id")),
            PaymentCode   = rd.GetString(rd.GetOrdinal("PaymentCode")),
            PaymentType   = rd.GetString(rd.GetOrdinal("PaymentType")),
            RecipientName = rd.GetString(rd.GetOrdinal("RecipientName")),
            Amount        = rd.GetDecimal(rd.GetOrdinal("Amount")),
            PaymentDate   = rd.GetDateTime(rd.GetOrdinal("PaymentDate")),
            PaymentMode   = rd.IsDBNull(rd.GetOrdinal("PaymentMode"))  ? "" : rd.GetString(rd.GetOrdinal("PaymentMode")),
            Description   = rd.IsDBNull(rd.GetOrdinal("Description"))  ? "" : rd.GetString(rd.GetOrdinal("Description")),
            FundPoolName  = rd.IsDBNull(rd.GetOrdinal("FundPoolName")) ? "" : rd.GetString(rd.GetOrdinal("FundPoolName")),
            Reference     = rd.IsDBNull(rd.GetOrdinal("Reference"))    ? "" : rd.GetString(rd.GetOrdinal("Reference")),
            CreatedAt     = rd.GetDateTime(rd.GetOrdinal("CreatedAt")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }
}
