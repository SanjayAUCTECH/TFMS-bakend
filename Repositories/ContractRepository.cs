using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class ContractRepository : IContractRepository
{
    private readonly IDbConnectionFactory _factory;
    public ContractRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Contract> Data, int TotalRecords)> GetAllAsync(ContractListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContracts", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId",      (object?)request.TenantId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",      (object?)request.DateFrom  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",        (object?)request.DateTo    ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Contract>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapContract(r));
        await r.CloseAsync();
        int totalCount = (int)(total.Value == DBNull.Value ? 0 : total.Value);

        // Load RoomIds for each contract
        if (list.Count > 0) {
            var contractIds = string.Join(",", list.Select(c => $"'{c.ContractId}'"));
            await using var cmd2 = new SqlCommand(
                $"SELECT ContractId, RoomId FROM ContractRooms WHERE ContractId IN ({contractIds})", conn);
            await using var r2 = await cmd2.ExecuteReaderAsync();
            var roomMap = new Dictionary<string, List<int>>();
            while (await r2.ReadAsync()) {
                var cid = r2.GetString(0);
                var rid = r2.GetInt32(1);
                if (!roomMap.ContainsKey(cid)) roomMap[cid] = new();
                roomMap[cid].Add(rid);
            }
            foreach (var c in list)
                c.RoomIds = roomMap.TryGetValue(c.ContractId, out var ids) ? ids : new();
        }

        return (list, totalCount);
    }

    public async Task<Contract?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await ReadContractWithPayments(cmd);
    }

    public async Task<Contract?> GetByContractIdAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetContractByContractId", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        return await ReadContractWithPayments(cmd);
    }

    public async Task<string> CreateAsync(Contract contract)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TenantId",              contract.TenantId);
        cmd.Parameters.AddWithValue("@CampId",                contract.CampId);
        cmd.Parameters.AddWithValue("@StartDate",             contract.StartDate);
        cmd.Parameters.AddWithValue("@Months",                contract.Months);
        var roomIdsJson = System.Text.Json.JsonSerializer.Serialize(contract.RoomIds);
        cmd.Parameters.AddWithValue("@RoomIdsJson",           roomIdsJson);
        cmd.Parameters.AddWithValue("@SecurityDeposit",       contract.SecurityDeposit);
        cmd.Parameters.AddWithValue("@InstallmentType",       contract.InstallmentType);
        cmd.Parameters.AddWithValue("@IssuedBy",              contract.IssuedBy);
        cmd.Parameters.AddWithValue("@Notes",                 contract.Notes);
        cmd.Parameters.AddWithValue("@LessorAmount",          contract.LessorAmount);
        cmd.Parameters.AddWithValue("@MonthlyTotal",          contract.MonthlyTotal > 0 ? (object)contract.MonthlyTotal : DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractTotal",         contract.ContractTotal > 0 ? (object)contract.ContractTotal : DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractPropertyUsage", contract.ContractPropertyUsage);
        cmd.Parameters.AddWithValue("@ContractBuildingName",  contract.ContractBuildingName);
        cmd.Parameters.AddWithValue("@ContractPropertyType",  contract.ContractPropertyType);
        cmd.Parameters.AddWithValue("@ContractLocation",      contract.ContractLocation);
        cmd.Parameters.AddWithValue("@ContractPropertyNo",    contract.ContractPropertyNo);
        cmd.Parameters.AddWithValue("@ContractPropertyArea",  contract.ContractPropertyArea);
        cmd.Parameters.AddWithValue("@ContractPremisesNo",    contract.ContractPremisesNo);
        cmd.Parameters.AddWithValue("@ContractPaymentMode",   contract.ContractPaymentMode);
        var newContractId = new SqlParameter("@NewContractId", SqlDbType.NVarChar, 20) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newContractId);
        await cmd.ExecuteNonQueryAsync();
        return (string)newContractId.Value;
    }

    public async Task<bool> UpdateStatusAsync(string contractId, string status)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateContractStatus", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        cmd.Parameters.AddWithValue("@Status",     status);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> UpdateContractAsync(UpdateContractRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateContract", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId",              request.ContractId);
        cmd.Parameters.AddWithValue("@TenantId",                request.TenantId);
        cmd.Parameters.AddWithValue("@StartDate",               request.StartDate);
        cmd.Parameters.AddWithValue("@Months",                  request.Months);
        cmd.Parameters.AddWithValue("@RoomIdsJson",             System.Text.Json.JsonSerializer.Serialize(request.RoomIds));
        cmd.Parameters.AddWithValue("@LessorAmount",            request.LessorAmount);
        cmd.Parameters.AddWithValue("@Notes",                   request.Notes ?? "");
        cmd.Parameters.AddWithValue("@MonthlyTotal",            request.MonthlyTotal.HasValue && request.MonthlyTotal > 0 ? (object)request.MonthlyTotal.Value : DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractTotal",           request.ContractTotal.HasValue && request.ContractTotal > 0 ? (object)request.ContractTotal.Value : DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractPropertyUsage",   request.ContractPropertyUsage  ?? "");
        cmd.Parameters.AddWithValue("@ContractBuildingName",    request.ContractBuildingName   ?? "");
        cmd.Parameters.AddWithValue("@ContractPropertyType",    request.ContractPropertyType   ?? "");
        cmd.Parameters.AddWithValue("@ContractLocation",        request.ContractLocation       ?? "");
        cmd.Parameters.AddWithValue("@ContractPropertyNo",      request.ContractPropertyNo     ?? "");
        cmd.Parameters.AddWithValue("@ContractPropertyArea",    request.ContractPropertyArea   ?? "");
        cmd.Parameters.AddWithValue("@ContractPremisesNo",      request.ContractPremisesNo     ?? "");
        cmd.Parameters.AddWithValue("@ContractPaymentMode",     request.ContractPaymentMode    ?? "");
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    public async Task<bool> UpdateScheduleAsync(string contractId, string scheduleJson)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdatePaymentSchedule", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@ContractId",   contractId);
        cmd.Parameters.AddWithValue("@ScheduleJson", scheduleJson);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    private static async Task<Contract?> ReadContractWithPayments(SqlCommand cmd)
    {
        Contract? contract = null;
        var roomIds  = new HashSet<int>();
        var payments = new List<Payment>();

        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            // Map contract once
            if (contract == null) contract = MapContract(r);

            // RoomId column
            try {
                var roomIdOrd = r.GetOrdinal("RoomId");
                if (!r.IsDBNull(roomIdOrd))
                    roomIds.Add(r.GetInt32(roomIdOrd));
            } catch { /* column may not exist */ }

            // Payment columns
            try {
                var payIdOrd = r.GetOrdinal("PayId");
                if (!r.IsDBNull(payIdOrd)) {
                    var payId = r.GetInt32(payIdOrd);
                    if (!payments.Any(p => p.Id == payId)) {
                        payments.Add(new Payment {
                            Id            = payId,
                            ContractId    = r.GetString(r.GetOrdinal("ContractId")),
                            InstallmentNo = r.GetInt32(r.GetOrdinal("InstallmentNo")),
                            Amount        = r.GetDecimal(r.GetOrdinal("PayAmount")),
                            DueDate       = r.GetDateTime(r.GetOrdinal("DueDate")),
                            PaidAmount    = r.GetDecimal(r.GetOrdinal("PaidAmount")),
                            PaidDate      = r.IsDBNull(r.GetOrdinal("PaidDate")) ? null : r.GetDateTime(r.GetOrdinal("PaidDate")),
                            Status        = r.GetString(r.GetOrdinal("PayStatus")),
                            PaymentMode   = r.IsDBNull(r.GetOrdinal("PaymentMode"))   ? "" : r.GetString(r.GetOrdinal("PaymentMode")),
                            ChequeNumber  = r.IsDBNull(r.GetOrdinal("ChequeNumber"))  ? "" : r.GetString(r.GetOrdinal("ChequeNumber")),
                            ClearanceDate = r.IsDBNull(r.GetOrdinal("ClearanceDate")) ? "" : r.GetString(r.GetOrdinal("ClearanceDate")),
                        });
                    }
                }
            } catch { /* column may not exist */ }
        }

        if (contract != null) {
            contract.RoomIds  = roomIds.ToList();
            contract.Payments = payments;
        }
        return contract;
    }

    private static Contract MapContract(SqlDataReader r) => new()
    {
        Id              = r.GetInt32(r.GetOrdinal("Id")),
        ContractId      = r.GetString(r.GetOrdinal("ContractId")),
        TenantId        = r.GetInt32(r.GetOrdinal("TenantId")),
        TenantName      = r.IsDBNull(r.GetOrdinal("TenantName"))    ? "" : r.GetString(r.GetOrdinal("TenantName")),
        CampId          = r.GetInt32(r.GetOrdinal("CampId")),
        CampName        = r.IsDBNull(r.GetOrdinal("CampName"))      ? "" : r.GetString(r.GetOrdinal("CampName")),
        StartDate       = r.GetDateTime(r.GetOrdinal("StartDate")),
        Months          = r.GetInt32(r.GetOrdinal("Months")),
        EndDate         = r.GetDateTime(r.GetOrdinal("EndDate")),
        MonthlyTotal    = r.GetDecimal(r.GetOrdinal("MonthlyTotal")),
        ContractTotal   = r.GetDecimal(r.GetOrdinal("ContractTotal")),
        SecurityDeposit = HasColumn(r,"SecurityDeposit") && !r.IsDBNull(r.GetOrdinal("SecurityDeposit")) ? r.GetDecimal(r.GetOrdinal("SecurityDeposit")) : 0,
        InstallmentType = HasColumn(r,"InstallmentType") && !r.IsDBNull(r.GetOrdinal("InstallmentType")) ? r.GetString(r.GetOrdinal("InstallmentType")) : "monthly",
        IssuedBy        = HasColumn(r,"IssuedBy")        && !r.IsDBNull(r.GetOrdinal("IssuedBy"))        ? r.GetString(r.GetOrdinal("IssuedBy"))        : "",
        Notes           = HasColumn(r,"Notes")           && !r.IsDBNull(r.GetOrdinal("Notes"))           ? r.GetString(r.GetOrdinal("Notes"))           : "",
        LessorAmount    = HasColumn(r,"LessorAmount")    && !r.IsDBNull(r.GetOrdinal("LessorAmount"))    ? r.GetDecimal(r.GetOrdinal("LessorAmount"))    : 0,
        ContractPropertyUsage = SafeStr(r, "ContractPropertyUsage"),
        ContractBuildingName  = SafeStr(r, "ContractBuildingName"),
        ContractPropertyType  = SafeStr(r, "ContractPropertyType"),
        ContractLocation      = SafeStr(r, "ContractLocation"),
        ContractPropertyNo    = SafeStr(r, "ContractPropertyNo"),
        ContractPropertyArea  = SafeStr(r, "ContractPropertyArea"),
        ContractPremisesNo    = SafeStr(r, "ContractPremisesNo"),
        ContractPaymentMode   = SafeStr(r, "ContractPaymentMode"),
        Status          = r.GetString(r.GetOrdinal("Status")),
        TotalPaid         = HasColumn(r, "TotalPaid")           && !r.IsDBNull(r.GetOrdinal("TotalPaid"))
                            ? Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalPaid"))) : 0,
        TotalDue          = HasColumn(r, "TotalDue")            && !r.IsDBNull(r.GetOrdinal("TotalDue"))
                            ? Convert.ToDecimal(r.GetValue(r.GetOrdinal("TotalDue")))  : 0,
        LastPaymentAmount = HasColumn(r, "LastPaymentAmount")   && !r.IsDBNull(r.GetOrdinal("LastPaymentAmount"))
                            ? Convert.ToDecimal(r.GetValue(r.GetOrdinal("LastPaymentAmount"))) : (decimal?)null,
        LastPaymentDate   = HasColumn(r, "LastPaymentDate")     && !r.IsDBNull(r.GetOrdinal("LastPaymentDate"))
                            ? r.GetDateTime(r.GetOrdinal("LastPaymentDate")) : (DateTime?)null,
        CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt       = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };

    private static string SafeStr(SqlDataReader r, string col)
    {
        try { var ord = r.GetOrdinal(col); return r.IsDBNull(ord) ? "" : r.GetString(ord); }
        catch { return ""; }
    }

    private static bool HasColumn(SqlDataReader r, string name)
    {
        for (int i = 0; i < r.FieldCount; i++)
            if (r.GetName(i).Equals(name, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    // ── GetDocumentAsync — full data for 2-page / 3-page contract preview ──
    public async Task<ContractDocResponse?> GetDocumentAsync(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // ── 1. Contract + Tenant + Camp ─────────────────────────────────
        ContractDocResponse? doc = null;
        await using (var cmd = new SqlCommand(@"
            SELECT
                c.Id, c.ContractId, c.Status, c.StartDate, c.EndDate, c.Months,
                c.MonthlyTotal, c.ContractTotal,
                ISNULL(c.SecurityDeposit,0) SecurityDeposit,
                ISNULL(c.InstallmentType,'monthly') InstallmentType,
                ISNULL(c.IssuedBy,'')  IssuedBy,
                ISNULL(c.Notes,'')     Notes,
                ISNULL(c.LessorAmount,0) LessorAmount,
                c.CreatedAt,
                -- Camp
                c.CampId, ca.Name CampName, ca.Code CampCode,
                -- Tenant
                t.Id TenantId, t.Name TenantName, t.Type TenantType,
                ISNULL(t.EmiratesId,'')          TenantEmiratesId,
                ISNULL(t.Passport,'')            TenantPassport,
                ISNULL(t.Nationality,'')         TenantNationality,
                ISNULL(t.Contact,'')             TenantContact,
                ISNULL(t.Whatsapp,'')            TenantWhatsapp,
                ISNULL(t.Email,'')               TenantEmail,
                ISNULL(t.Address,'')             TenantAddress,
                ISNULL(t.Company,'')             TenantCompany,
                ISNULL(t.TradeLicense,'')        TenantTradeLicense,
                ISNULL(t.LicensingAuthority,'')  TenantLicAuthority,
                ISNULL(t.NumberOfCoOccupants,'1') TenantCoOccupants,
                -- Property (EJARI)
                ISNULL(t.PlotNo,'')       PlotNo,
                ISNULL(t.MakaniNo,'')     MakaniNo,
                ISNULL(t.PropertyArea,'') PropertyArea,
                ISNULL(t.PremisesNo,'')   PremisesNo,
                -- Lessor
                ISNULL(t.LessorName,'')         LessorName,
                ISNULL(t.LessorEid,'')          LessorEid,
                ISNULL(t.LessorLicense,'')      LessorLicense,
                ISNULL(t.LessorLicAuthority,'') LessorLicAuthority,
                ISNULL(t.LessorEmail,'')        LessorEmail,
                ISNULL(t.LessorPhone,'')        LessorPhone,
                -- Payment summary
                ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId=c.ContractId),0) TotalPaid,
                c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId=c.ContractId),0) TotalDue,
                ISNULL((SELECT SUM(w.WaiverAmount) FROM Waivers w WHERE w.ContractId=c.ContractId),0) TotalWaived,
                (SELECT COUNT(*) FROM ContractInstallments WHERE ContractId=c.ContractId) TotalInstallments,
                (SELECT COUNT(*) FROM ContractInstallments WHERE ContractId=c.ContractId AND Status='Paid') PaidInstallments,
                (SELECT COUNT(*) FROM ContractInstallments WHERE ContractId=c.ContractId AND Status IN('Pending','Partial','Overdue')) PendingInstallments,
                (SELECT TOP 1 Amount FROM TxnRecords WHERE ContractId=c.ContractId AND TxnType='CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
                (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId=c.ContractId AND TxnType='CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate
            FROM Contracts c
            JOIN Tenants t  ON t.Id  = c.TenantId
            JOIN Camps   ca ON ca.Id = c.CampId
            WHERE c.ContractId = @ContractId", conn))
        {
            cmd.Parameters.AddWithValue("@ContractId", contractId);
            await using var r = await cmd.ExecuteReaderAsync();
            if (await r.ReadAsync())
            {
                doc = new ContractDocResponse
                {
                    Id              = r.GetInt32(r.GetOrdinal("Id")),
                    ContractId      = r.GetString(r.GetOrdinal("ContractId")),
                    Status          = r.GetString(r.GetOrdinal("Status")),
                    StartDate       = r.GetDateTime(r.GetOrdinal("StartDate")),
                    EndDate         = r.GetDateTime(r.GetOrdinal("EndDate")),
                    Months          = r.GetInt32(r.GetOrdinal("Months")),
                    MonthlyTotal    = r.GetDecimal(r.GetOrdinal("MonthlyTotal")),
                    ContractTotal   = r.GetDecimal(r.GetOrdinal("ContractTotal")),
                    SecurityDeposit = r.GetDecimal(r.GetOrdinal("SecurityDeposit")),
                    InstallmentType = r.GetString(r.GetOrdinal("InstallmentType")),
                    IssuedBy        = r.GetString(r.GetOrdinal("IssuedBy")),
                    Notes           = r.GetString(r.GetOrdinal("Notes")),
                    LessorAmount    = r.GetDecimal(r.GetOrdinal("LessorAmount")),
                    CreatedAt       = r.GetDateTime(r.GetOrdinal("CreatedAt")),
                    CampId          = r.GetInt32(r.GetOrdinal("CampId")),
                    CampName        = r.GetString(r.GetOrdinal("CampName")),
                    CampCode        = r.GetString(r.GetOrdinal("CampCode")),
                    TenantId          = r.GetInt32(r.GetOrdinal("TenantId")),
                    TenantName        = r.GetString(r.GetOrdinal("TenantName")),
                    TenantType        = r.GetString(r.GetOrdinal("TenantType")),
                    TenantEmiratesId  = r.GetString(r.GetOrdinal("TenantEmiratesId")),
                    TenantPassport    = r.GetString(r.GetOrdinal("TenantPassport")),
                    TenantNationality = r.GetString(r.GetOrdinal("TenantNationality")),
                    TenantContact     = r.GetString(r.GetOrdinal("TenantContact")),
                    TenantWhatsapp    = r.GetString(r.GetOrdinal("TenantWhatsapp")),
                    TenantEmail       = r.GetString(r.GetOrdinal("TenantEmail")),
                    TenantAddress     = r.GetString(r.GetOrdinal("TenantAddress")),
                    TenantCompany     = r.GetString(r.GetOrdinal("TenantCompany")),
                    TenantTradeLicense= r.GetString(r.GetOrdinal("TenantTradeLicense")),
                    TenantLicAuthority= r.GetString(r.GetOrdinal("TenantLicAuthority")),
                    TenantCoOccupants = r.GetString(r.GetOrdinal("TenantCoOccupants")),
                    PlotNo          = r.GetString(r.GetOrdinal("PlotNo")),
                    MakaniNo        = r.GetString(r.GetOrdinal("MakaniNo")),
                    PropertyArea    = r.GetString(r.GetOrdinal("PropertyArea")),
                    PremisesNo      = r.GetString(r.GetOrdinal("PremisesNo")),
                    LessorName        = r.GetString(r.GetOrdinal("LessorName")),
                    LessorEid         = r.GetString(r.GetOrdinal("LessorEid")),
                    LessorLicense     = r.GetString(r.GetOrdinal("LessorLicense")),
                    LessorLicAuthority= r.GetString(r.GetOrdinal("LessorLicAuthority")),
                    LessorEmail       = r.GetString(r.GetOrdinal("LessorEmail")),
                    LessorPhone       = r.GetString(r.GetOrdinal("LessorPhone")),
                    TotalPaid           = r.IsDBNull(r.GetOrdinal("TotalPaid"))    ? 0 : r.GetDecimal(r.GetOrdinal("TotalPaid")),
                    TotalDue            = r.IsDBNull(r.GetOrdinal("TotalDue"))     ? 0 : r.GetDecimal(r.GetOrdinal("TotalDue")),
                    TotalWaived         = r.IsDBNull(r.GetOrdinal("TotalWaived"))  ? 0 : r.GetDecimal(r.GetOrdinal("TotalWaived")),
                    TotalInstallments   = r.IsDBNull(r.GetOrdinal("TotalInstallments"))   ? 0 : r.GetInt32(r.GetOrdinal("TotalInstallments")),
                    PaidInstallments    = r.IsDBNull(r.GetOrdinal("PaidInstallments"))    ? 0 : r.GetInt32(r.GetOrdinal("PaidInstallments")),
                    PendingInstallments = r.IsDBNull(r.GetOrdinal("PendingInstallments")) ? 0 : r.GetInt32(r.GetOrdinal("PendingInstallments")),
                    LastPaymentAmount   = r.IsDBNull(r.GetOrdinal("LastPaymentAmount"))   ? null : (decimal?)r.GetDecimal(r.GetOrdinal("LastPaymentAmount")),
                    LastPaymentDate     = r.IsDBNull(r.GetOrdinal("LastPaymentDate"))     ? null : r.GetDateTime(r.GetOrdinal("LastPaymentDate")).ToString("yyyy-MM-dd"),
                };
            }
        }
        if (doc == null) return null;

        // ── 2. Rooms ─────────────────────────────────────────────────────
        await using (var cmd2 = new SqlCommand(@"
            SELECT r.Id, r.RoomNo, ISNULL(f.Name,'') FloorName, r.MonthlyPrice
            FROM ContractRooms cr
            JOIN Rooms r  ON r.Id  = cr.RoomId
            LEFT JOIN Floors f ON f.Id = r.FloorId
            WHERE cr.ContractId = @ContractId
            ORDER BY r.RoomNo", conn))
        {
            cmd2.Parameters.AddWithValue("@ContractId", contractId);
            await using var r2 = await cmd2.ExecuteReaderAsync();
            while (await r2.ReadAsync())
                doc.Rooms.Add(new ContractDocRoom
                {
                    Id           = r2.GetInt32(r2.GetOrdinal("Id")),
                    RoomNo       = r2.GetString(r2.GetOrdinal("RoomNo")),
                    FloorName    = r2.GetString(r2.GetOrdinal("FloorName")),
                    MonthlyPrice = r2.GetDecimal(r2.GetOrdinal("MonthlyPrice")),
                });
        }

        // ── 3. Installments (payment schedule) ───────────────────────────
        await using (var cmd3 = new SqlCommand(@"
            SELECT Id, InstallmentNo, Amount, DueDate, PaidAmount, PaidDate, Status,
                   ISNULL(PaymentMode,'')   PaymentMode,
                   ISNULL(ChequeNumber,'')  ChequeNumber,
                   ISNULL(ClearanceDate,'') ClearanceDate,
                   ISNULL(ReceivedBy,'')    ReceivedBy,
                   ISNULL(FundPoolName,'')  FundPoolName,
                   ISNULL(Description,'')   Description
            FROM ContractInstallments
            WHERE ContractId = @ContractId
            ORDER BY InstallmentNo", conn))
        {
            cmd3.Parameters.AddWithValue("@ContractId", contractId);
            await using var r3 = await cmd3.ExecuteReaderAsync();
            while (await r3.ReadAsync())
                doc.Installments.Add(new ContractDocInstallment
                {
                    Id            = r3.GetInt32(r3.GetOrdinal("Id")),
                    InstallmentNo = r3.GetInt32(r3.GetOrdinal("InstallmentNo")),
                    Amount        = r3.GetDecimal(r3.GetOrdinal("Amount")),
                    DueDate       = r3.GetDateTime(r3.GetOrdinal("DueDate")).ToString("yyyy-MM-dd"),
                    PaidAmount    = r3.GetDecimal(r3.GetOrdinal("PaidAmount")),
                    BalanceAmount = r3.GetDecimal(r3.GetOrdinal("Amount")) - r3.GetDecimal(r3.GetOrdinal("PaidAmount")),
                    PaidDate      = r3.IsDBNull(r3.GetOrdinal("PaidDate")) ? null : r3.GetDateTime(r3.GetOrdinal("PaidDate")).ToString("yyyy-MM-dd"),
                    Status        = r3.GetString(r3.GetOrdinal("Status")),
                    PaymentMode   = r3.GetString(r3.GetOrdinal("PaymentMode")),
                    ChequeNumber  = r3.GetString(r3.GetOrdinal("ChequeNumber")),
                    ClearanceDate = r3.GetString(r3.GetOrdinal("ClearanceDate")),
                    ReceivedBy    = r3.GetString(r3.GetOrdinal("ReceivedBy")),
                    FundPoolName  = r3.GetString(r3.GetOrdinal("FundPoolName")),
                    Description   = r3.GetString(r3.GetOrdinal("Description")),
                });
        }

        return doc;
    }
}
