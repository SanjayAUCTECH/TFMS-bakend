using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonUngeneratedDataController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;

    public SalonUngeneratedDataController(IDbConnectionFactory factory)
    {
        _factory = factory;
    }

    /// <summary>
    /// GET api/SalonUngeneratedData
    /// Salon wise ungenerated collection, company expense and staff salary.
    /// Filters: salonId, dateFrom, dateTo
    ///
    /// UngeneratedCollection     = SDCollection SUM(Amount)
    /// UngeneratedCompanyExpense = CompanyExpensePosting SUM(Amount) where Head != 'SALARY'
    /// UngeneratedStaffSalary    = CompanyExpensePosting SUM(Amount) where Head = 'SALARY'
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetReport([FromQuery] SalonUngeneratedDataRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetSalonUngeneratedData", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 60
        };

        cmd.Parameters.AddWithValue("@SalonId",
            (object?)request.SalonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",
            string.IsNullOrEmpty(request.DateFrom) ? DBNull.Value : (object)DateTime.Parse(request.DateFrom));
        cmd.Parameters.AddWithValue("@DateTo",
            string.IsNullOrEmpty(request.DateTo)   ? DBNull.Value : (object)DateTime.Parse(request.DateTo));

        var response = new SalonUngeneratedDataResponse();

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            response.Rows.Add(new SalonUngeneratedDataRow
            {
                SalonId                   = reader.GetInt32(reader.GetOrdinal("SalonId")),
                SalonName                 = S(reader, "SalonName"),
                DateFrom                  = S(reader, "DateFrom"),
                DateTo                    = S(reader, "DateTo"),
                UngeneratedCollection     = D(reader, "UngeneratedCollection"),
                UngeneratedCompanyExpense = D(reader, "UngeneratedCompanyExpense"),
                UngeneratedStaffSalary    = D(reader, "UngeneratedStaffSalary"),
            });
        }
        await reader.CloseAsync();

        // Summary
        response.Summary = new SalonUngeneratedDataSummary
        {
            TotalUngeneratedCollection     = response.Rows.Sum(r => r.UngeneratedCollection),
            TotalUngeneratedCompanyExpense = response.Rows.Sum(r => r.UngeneratedCompanyExpense),
            TotalUngeneratedStaffSalary    = response.Rows.Sum(r => r.UngeneratedStaffSalary),
        };

        return Ok(ApiResponse<SalonUngeneratedDataResponse>.Ok(
            response,
            "Salon ungenerated data retrieved successfully."));
    }

    private static string  S(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? "" : r.GetString(o); } catch { return ""; } }
    private static decimal D(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? 0m : r.GetDecimal(o); } catch { return 0m; } }
}
