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
public class PartnerPayoutReportController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;

    public PartnerPayoutReportController(IDbConnectionFactory factory)
    {
        _factory = factory;
    }

    /// <summary>
    /// GET api/PartnerPayoutReport
    /// Partner payout report with closing balance, payout generated, paid amount, balance.
    /// Filters: month, year, partnerId, pageNumber, pageSize
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetPartnerPayoutReport([FromQuery] PartnerPayoutReportRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetPartnerPayoutReport", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 60
        };

        cmd.Parameters.AddWithValue("@Month",      (object?)request.Month     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Year",       (object?)request.Year      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PartnerId",  (object?)request.PartnerId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var response = new PartnerPayoutReportResponse();

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            response.Rows.Add(new PartnerPayoutReportRow
            {
                PartnerId            = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                PartnerCode          = S(reader, "PartnerCode"),
                PartnerName          = S(reader, "PartnerName"),
                Mobile               = S(reader, "Mobile"),
                Email                = S(reader, "Email"),
                Status               = S(reader, "Status"),
                ClosingBalance       = D(reader, "ClosingBalance"),
                PayoutGenerated      = D(reader, "PayoutGenerated"),
                TotalRemainingPayout = D(reader, "TotalRemainingPayout"),
                PaidAmount           = D(reader, "PaidAmount"),
                Balance              = D(reader, "Balance"),
            });
        }
        await reader.CloseAsync();

        int totalRecords = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        response.TotalRecords = totalRecords;

        // Build summary
        response.Summary = new PartnerPayoutReportSummary
        {
            TotalPartners        = totalRecords,
            TotalClosingBalance  = response.Rows.Sum(r => r.ClosingBalance),
            TotalPayoutGenerated = response.Rows.Sum(r => r.PayoutGenerated),
            TotalRemainingPayout = response.Rows.Sum(r => r.TotalRemainingPayout),
            TotalPaidAmount      = response.Rows.Sum(r => r.PaidAmount),
            TotalBalance         = response.Rows.Sum(r => r.Balance),
            ReportMonth          = (request.Month.HasValue && request.Year.HasValue)
                                       ? new DateTime(request.Year.Value, request.Month.Value, 1)
                                             .ToString("MMMM yyyy")   // e.g. "July 2026"
                                       : null,
        };

        return Ok(ApiResponse<PartnerPayoutReportResponse>.Ok(
            response,
            "Partner payout report retrieved successfully.",
            PaginationHelper.Build(totalRecords, request.ResolvedPageNumber, request.ResolvedPageSize)));
    }

    private static string  S(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? "" : r.GetString(o); } catch { return ""; } }
    private static decimal D(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? 0m : r.GetDecimal(o); } catch { return 0m; } }
}
