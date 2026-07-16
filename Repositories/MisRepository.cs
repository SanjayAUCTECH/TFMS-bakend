using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class MisRepository : IMisRepository
{
    private readonly IDbConnectionFactory _factory;
    public MisRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<MisStatsResponse> GetMisStatsAsync(MisRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetMisStats", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@CampId",  (object?)request.CampId  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",   (object?)request.Month   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PartnerId",(object?)request.PartnerId ?? DBNull.Value);
        await using var rd = await cmd.ExecuteReaderAsync();

        var result = new MisStatsResponse();

        // Result set 1: KPI totals
        if (await rd.ReadAsync())
        {
            result.TotalRental      = rd.IsDBNull(rd.GetOrdinal("TotalRental"))      ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("TotalRental")));
            result.TotalCollected   = rd.IsDBNull(rd.GetOrdinal("TotalCollected"))   ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("TotalCollected")));
            result.TotalOutstanding = rd.IsDBNull(rd.GetOrdinal("TotalOutstanding")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("TotalOutstanding")));
            result.TotalExpenses    = rd.IsDBNull(rd.GetOrdinal("TotalExpenses"))    ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("TotalExpenses")));
            result.NetProfit        = rd.IsDBNull(rd.GetOrdinal("NetProfit"))        ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("NetProfit")));
            result.TotalUnits       = rd.IsDBNull(rd.GetOrdinal("TotalUnits"))       ? 0 : Convert.ToInt32(rd.GetValue(rd.GetOrdinal("TotalUnits")));
            result.OccupiedUnits    = rd.IsDBNull(rd.GetOrdinal("OccupiedUnits"))    ? 0 : Convert.ToInt32(rd.GetValue(rd.GetOrdinal("OccupiedUnits")));
            result.VacantUnits      = rd.IsDBNull(rd.GetOrdinal("VacantUnits"))      ? 0 : Convert.ToInt32(rd.GetValue(rd.GetOrdinal("VacantUnits")));
            result.OccupancyPct     = rd.IsDBNull(rd.GetOrdinal("OccupancyPct"))     ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("OccupancyPct")));
        }

        // Result set 2: Camp breakdown
        await rd.NextResultAsync();
        while (await rd.ReadAsync())
        {
            result.CampBreakdown.Add(new MisCampRow
            {
                CampId           = rd.GetInt32(rd.GetOrdinal("CampId")),
                CampName         = rd.GetString(rd.GetOrdinal("CampName")),
                TotalRooms       = rd.IsDBNull(rd.GetOrdinal("TotalRooms"))       ? 0 : rd.GetInt32(rd.GetOrdinal("TotalRooms")),
                OccupiedRooms    = rd.IsDBNull(rd.GetOrdinal("OccupiedRooms"))    ? 0 : rd.GetInt32(rd.GetOrdinal("OccupiedRooms")),
                MonthlyRevenue   = rd.IsDBNull(rd.GetOrdinal("MonthlyRevenue"))   ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("MonthlyRevenue"))),
                TotalCollected   = rd.IsDBNull(rd.GetOrdinal("TotalCollected"))   ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("TotalCollected"))),
                TotalOutstanding = rd.IsDBNull(rd.GetOrdinal("TotalOutstanding")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("TotalOutstanding"))),
            });
        }

        // Result set 3: Monthly collections
        await rd.NextResultAsync();
        while (await rd.ReadAsync())
        {
            result.MonthlyCollection.Add(new MisMonthlyRow
            {
                Month      = rd.IsDBNull(rd.GetOrdinal("Month"))     ? "" : rd.GetString(rd.GetOrdinal("Month")),
                Collected  = rd.IsDBNull(rd.GetOrdinal("Collected")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("Collected"))),
                Due        = rd.IsDBNull(rd.GetOrdinal("Due"))       ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("Due"))),
                Expenses   = rd.IsDBNull(rd.GetOrdinal("Expenses"))  ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("Expenses"))),
                NetProfit  = rd.IsDBNull(rd.GetOrdinal("NetProfit")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("NetProfit"))),
            });
        }

        // Result set 4: Expense by head
        await rd.NextResultAsync();
        while (await rd.ReadAsync())
        {
            result.ExpenseByHead.Add(new MisExpenseHeadRow
            {
                Head   = rd.IsDBNull(rd.GetOrdinal("Head"))   ? "" : rd.GetString(rd.GetOrdinal("Head")),
                Amount = rd.IsDBNull(rd.GetOrdinal("Amount")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("Amount"))),
            });
        }

        return result;
    }

    public async Task<(IEnumerable<OwnerReportRow> Data, int Total)> GetOwnerReportAsync(ReportRequest r)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetOwnerReport", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", r.ResolvedPage);
        cmd.Parameters.AddWithValue("@PageSize",   r.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText", (object?)r.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)r.Status     ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<OwnerReportRow>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync()) list.Add(new OwnerReportRow
        {
            OwnerId    = rd.GetInt32(rd.GetOrdinal("OwnerId")),
            OwnerCode  = rd.GetString(rd.GetOrdinal("OwnerCode")),
            OwnerName  = rd.GetString(rd.GetOrdinal("OwnerName")),
            Contact    = rd.IsDBNull(rd.GetOrdinal("Contact"))   ? "" : rd.GetString(rd.GetOrdinal("Contact")),
            Email      = rd.IsDBNull(rd.GetOrdinal("Email"))     ? "" : rd.GetString(rd.GetOrdinal("Email")),
            Status     = rd.GetString(rd.GetOrdinal("Status")),
            TotalCamps = rd.IsDBNull(rd.GetOrdinal("TotalCamps")) ? 0 : rd.GetInt32(rd.GetOrdinal("TotalCamps")),
            CampNames  = rd.IsDBNull(rd.GetOrdinal("CampNames"))  ? "" : rd.GetString(rd.GetOrdinal("CampNames")),
            ShareValue = rd.IsDBNull(rd.GetOrdinal("ShareValue")) ? 0 : rd.GetDecimal(rd.GetOrdinal("ShareValue")),
            ShareType  = rd.IsDBNull(rd.GetOrdinal("ShareType"))  ? "" : rd.GetString(rd.GetOrdinal("ShareType")),
        });
        await rd.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }
}
