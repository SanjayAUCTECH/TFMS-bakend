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
public class CampWisePartnerBalanceReportController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;

    public CampWisePartnerBalanceReportController(IDbConnectionFactory factory)
    {
        _factory = factory;
    }

    /// <summary>
    /// GET api/CampWisePartnerBalanceReport
    /// Camp aur partner wise balance report.
    /// Filters: month, year, partnerId, campId, pageNumber, pageSize
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetReport([FromQuery] CampWisePartnerBalanceReportRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetCampWisePartnerBalanceReport", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 60
        };

        cmd.Parameters.AddWithValue("@Month",      (object?)request.Month     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Year",       (object?)request.Year      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PartnerId",  (object?)request.PartnerId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)request.CampId    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var response = new CampWisePartnerBalanceReportResponse();

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            response.Rows.Add(new CampWisePartnerBalanceRow
            {
                CampId            = reader.GetInt32(reader.GetOrdinal("CampId")),
                CampCode          = S(reader, "CampCode"),
                CampName          = S(reader, "CampName"),
                PartnerId         = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                PartnerCode       = S(reader, "PartnerCode"),
                PartnerName       = S(reader, "PartnerName"),
                PartnerPercentage = D(reader, "PartnerPercentage"),
                ClosingBalance    = D(reader, "ClosingBalance"),
                PayoutGenerated   = D(reader, "PayoutGenerated"),
                TotalPayout       = D(reader, "TotalPayout"),
                Paid              = D(reader, "Paid"),
                FinalBalance      = D(reader, "FinalBalance"),
            });
        }
        await reader.CloseAsync();

        int totalRecords = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        response.TotalRecords = totalRecords;

        // Build summary
        response.Summary = new CampWisePartnerBalanceSummary
        {
            TotalRows            = totalRecords,
            TotalClosingBalance  = response.Rows.Sum(r => r.ClosingBalance),
            TotalPayoutGenerated = response.Rows.Sum(r => r.PayoutGenerated),
            TotalPayout          = response.Rows.Sum(r => r.TotalPayout),
            TotalPaid            = response.Rows.Sum(r => r.Paid),
            TotalFinalBalance    = response.Rows.Sum(r => r.FinalBalance),
            ReportMonth          = (request.Month.HasValue && request.Year.HasValue)
                                       ? new DateTime(request.Year.Value, request.Month.Value, 1)
                                             .ToString("MMMM yyyy")
                                       : null,
        };

        return Ok(ApiResponse<CampWisePartnerBalanceReportResponse>.Ok(
            response,
            "Camp wise partner balance report retrieved successfully.",
            PaginationHelper.Build(totalRecords, request.ResolvedPageNumber, request.ResolvedPageSize)));
    }

    private static string  S(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? "" : r.GetString(o); } catch { return ""; } }
    private static decimal D(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? 0m : r.GetDecimal(o); } catch { return 0m; } }
}
