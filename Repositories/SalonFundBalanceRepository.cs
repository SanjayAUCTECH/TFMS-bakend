using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class SalonFundBalanceRepository : ISalonFundBalanceRepository
{
    private readonly IDbConnectionFactory _factory;
    public SalonFundBalanceRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<SalonFundBalanceResponse> GetBalanceAsync(SalonFundBalanceRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonFundBalance", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@SalonId",  (object?)request.SalonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo)   ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        await using var reader = await cmd.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return new SalonFundBalanceResponse
            {
                CurrentClosingDateFrom       = reader.IsDBNull(reader.GetOrdinal("CurrentClosingDateFrom")) ? null : reader.GetDateTime(reader.GetOrdinal("CurrentClosingDateFrom")),
                CurrentClosingDateTo         = reader.IsDBNull(reader.GetOrdinal("CurrentClosingDateTo"))   ? null : reader.GetDateTime(reader.GetOrdinal("CurrentClosingDateTo")),

                StaffPreviousMonthClosing    = reader.IsDBNull(reader.GetOrdinal("StaffPreviousMonthClosing"))  ? 0 : reader.GetDecimal(reader.GetOrdinal("StaffPreviousMonthClosing")),
                StaffCurrentClosing          = reader.IsDBNull(reader.GetOrdinal("StaffCurrentClosing"))        ? 0 : reader.GetDecimal(reader.GetOrdinal("StaffCurrentClosing")),
                TotalStaffShare              = reader.IsDBNull(reader.GetOrdinal("TotalStaffShare"))            ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalStaffShare")),
                StaffSalaryPaid              = reader.IsDBNull(reader.GetOrdinal("StaffSalaryPaid"))            ? 0 : reader.GetDecimal(reader.GetOrdinal("StaffSalaryPaid")),
                StaffClosingBalance          = reader.IsDBNull(reader.GetOrdinal("StaffClosingBalance"))        ? 0 : reader.GetDecimal(reader.GetOrdinal("StaffClosingBalance")),

                CompanyPreviousMonthClosing  = reader.IsDBNull(reader.GetOrdinal("CompanyPreviousMonthClosing")) ? 0 : reader.GetDecimal(reader.GetOrdinal("CompanyPreviousMonthClosing")),
                CompanyCurrentClosing        = reader.IsDBNull(reader.GetOrdinal("CompanyCurrentClosing"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("CompanyCurrentClosing")),
                TotalCompanyRevenue          = reader.IsDBNull(reader.GetOrdinal("TotalCompanyRevenue"))         ? 0 : reader.GetDecimal(reader.GetOrdinal("TotalCompanyRevenue")),
                CompanyExpense               = reader.IsDBNull(reader.GetOrdinal("CompanyExpense"))              ? 0 : reader.GetDecimal(reader.GetOrdinal("CompanyExpense")),
                CompanyClosingBalance        = reader.IsDBNull(reader.GetOrdinal("CompanyClosingBalance"))       ? 0 : reader.GetDecimal(reader.GetOrdinal("CompanyClosingBalance")),
            };
        }

        return new SalonFundBalanceResponse();
    }
}
