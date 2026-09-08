using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class SalonStaffReportRepository : ISalonStaffReportRepository
{
    private readonly IDbConnectionFactory _factory;
    public SalonStaffReportRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<SalonStaffReportRow> Data, int Total, SalonStaffReportCards Cards)> GetReportAsync(
        SalonStaffReportRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonStaffReport", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@SalonId",  (object?)request.SalonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@StaffId",  (object?)request.StaffId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom", string.IsNullOrEmpty(request.DateFrom)
            ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",   string.IsNullOrEmpty(request.DateTo)
            ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list  = new List<SalonStaffReportRow>();
        var cards = new SalonStaffReportCards();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result set 1: Staff-wise detail rows ───────────────────────────
        while (await reader.ReadAsync())
        {
            list.Add(new SalonStaffReportRow
            {
                AssignId        = reader.GetInt32(reader.GetOrdinal("AssignId")),
                StaffId         = reader.GetInt32(reader.GetOrdinal("StaffId")),
                StaffName       = reader["StaffName"]?.ToString(),
                Percentage      = reader.IsDBNull(reader.GetOrdinal("Percentage"))      ? 0    : reader.GetDecimal(reader.GetOrdinal("Percentage")),
                AssignStatus    = reader["AssignStatus"]?.ToString(),
                PayoutDateFrom  = reader.IsDBNull(reader.GetOrdinal("PayoutDateFrom"))  ? null : reader.GetDateTime(reader.GetOrdinal("PayoutDateFrom")),
                PayoutDateTo    = reader.IsDBNull(reader.GetOrdinal("PayoutDateTo"))    ? null : reader.GetDateTime(reader.GetOrdinal("PayoutDateTo")),
                TotalCollection = reader.IsDBNull(reader.GetOrdinal("TotalCollection")) ? 0    : reader.GetDecimal(reader.GetOrdinal("TotalCollection")),
                TotalDCExpense  = reader.IsDBNull(reader.GetOrdinal("TotalDCExpense"))  ? 0    : reader.GetDecimal(reader.GetOrdinal("TotalDCExpense")),
                TotalCOExpense  = reader.IsDBNull(reader.GetOrdinal("TotalCOExpense"))  ? 0    : reader.GetDecimal(reader.GetOrdinal("TotalCOExpense")),
                StaffProfit     = reader.IsDBNull(reader.GetOrdinal("StaffProfit"))     ? 0    : reader.GetDecimal(reader.GetOrdinal("StaffProfit")),
                CompanyRevenue  = reader.IsDBNull(reader.GetOrdinal("CompanyRevenue"))  ? 0    : reader.GetDecimal(reader.GetOrdinal("CompanyRevenue")),
                SalaryPaid      = reader.IsDBNull(reader.GetOrdinal("SalaryPaid"))      ? 0    : reader.GetDecimal(reader.GetOrdinal("SalaryPaid")),
            });
        }

        // ── Result set 2: Summary cards ────────────────────────────────────
        await reader.NextResultAsync();
        if (await reader.ReadAsync())
        {
            cards = new SalonStaffReportCards
            {
                TotalStaff            = reader.IsDBNull(reader.GetOrdinal("TotalStaff"))            ? 0 : reader.GetInt32(reader.GetOrdinal("TotalStaff")),
                TotalSalons           = reader.IsDBNull(reader.GetOrdinal("TotalSalons"))           ? 0 : reader.GetInt32(reader.GetOrdinal("TotalSalons")),
                TotalCollection       = reader.IsDBNull(reader.GetOrdinal("TotalCollection"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalCollection")),
                TotalStaffProfit      = reader.IsDBNull(reader.GetOrdinal("TotalStaffProfit"))      ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalStaffProfit")),
                TotalSalaryPaid       = reader.IsDBNull(reader.GetOrdinal("TotalSalaryPaid"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalSalaryPaid")),
                TotalRemainingBalance = reader.IsDBNull(reader.GetOrdinal("TotalRemainingBalance")) ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalRemainingBalance")),
                TotalCompanyRevenue   = reader.IsDBNull(reader.GetOrdinal("TotalCompanyRevenue"))   ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalCompanyRevenue")),
            };
        }

        // ── Result set 3: Salary payment detail (date-wise per staff) ──────
        await reader.NextResultAsync();
        var salaryDict = new Dictionary<int, List<SalaryPaymentDetail>>();
        while (await reader.ReadAsync())
        {
            int staffId = reader.GetInt32(reader.GetOrdinal("StaffId"));
            var detail  = new SalaryPaymentDetail
            {
                StaffId      = staffId,
                SalaryDate   = reader.GetDateTime(reader.GetOrdinal("SalaryDate")),
                SalaryAmount = reader.IsDBNull(reader.GetOrdinal("SalaryAmount")) ? 0    : reader.GetDecimal(reader.GetOrdinal("SalaryAmount")),
                Mode         = reader["Mode"]?.ToString(),
                Description  = reader.IsDBNull(reader.GetOrdinal("Description"))  ? null : reader["Description"].ToString(),
            };
            if (!salaryDict.ContainsKey(staffId))
                salaryDict[staffId] = new List<SalaryPaymentDetail>();
            salaryDict[staffId].Add(detail);
        }

        await reader.CloseAsync();

        // Attach salary payments array to each staff row
        foreach (var row in list)
        {
            if (salaryDict.TryGetValue(row.StaffId, out var payments))
                row.SalaryPayments = payments;
        }

        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        return (list, total, cards);
    }
}
