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
public class FundPoolReportController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;

    public FundPoolReportController(IDbConnectionFactory factory)
    {
        _factory = factory;
    }

    /// <summary>
    /// GET api/FundPoolReport
    /// Fund pool report with income, expense, buffer, payment totals.
    /// Filters: fundPoolId, searchText, status, month, year, dateFrom, dateTo, pageNumber, pageSize
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetFundPoolReport([FromQuery] FundPoolReportRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetFundPoolReport", conn)
        {
            CommandType  = CommandType.StoredProcedure,
            CommandTimeout = 60
        };

        cmd.Parameters.AddWithValue("@FundPoolId",  (object?)request.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SearchText",  (object?)request.SearchText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",      (object?)request.Status     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",       (object?)request.Month      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Year",        (object?)request.Year       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",    request.DateFrom.HasValue ? (object)request.DateFrom.Value.Date : DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",      request.DateTo.HasValue   ? (object)request.DateTo.Value.Date   : DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber",  request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",    request.ResolvedPageSize == int.MaxValue ? 1000 : request.ResolvedPageSize);

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var response = new FundPoolReportResponse();

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Current Fund Pool rows ──────────────────
        while (await reader.ReadAsync())
        {
            response.Rows.Add(new FundPoolReportRow
            {
                FundPoolId            = reader.GetInt32(reader.GetOrdinal("FundPoolId")),
                FundPoolCode          = S(reader, "FundPoolCode"),
                FundPoolName          = S(reader, "FundPoolName"),
                Status                = S(reader, "Status"),
                CurrentBalance        = D(reader, "CurrentBalance"),
                TotalIncome           = D(reader, "TotalIncome"),
                TotalExpense          = D(reader, "TotalExpense"),
                TotalPaymentsReceived = D(reader, "TotalPaymentsReceived"),
                NetAmount             = D(reader, "NetAmount"),
                BufferAmount          = D(reader, "BufferAmount"),
                BufferTotalIncome     = D(reader, "BufferTotalIncome"),
                BufferTotalExpense    = D(reader, "BufferTotalExpense"),
                BufferTotalAmount     = D(reader, "BufferTotalAmount"),
                BufferNetAmount       = D(reader, "BufferNetAmount"),
                IncomeCount           = reader.IsDBNull(reader.GetOrdinal("IncomeCount"))  ? 0 : reader.GetInt32(reader.GetOrdinal("IncomeCount")),
                ExpenseCount          = reader.IsDBNull(reader.GetOrdinal("ExpenseCount")) ? 0 : reader.GetInt32(reader.GetOrdinal("ExpenseCount")),
                PaymentCount          = reader.IsDBNull(reader.GetOrdinal("PaymentCount")) ? 0 : reader.GetInt32(reader.GetOrdinal("PaymentCount")),
                CreatedAt             = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt             = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
            });
        }

        // ── Result Set 2: Buffer Fund Pool rows ───────────────────
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                response.BufferRows.Add(new FundPoolBufferRow
                {
                    FundPoolId            = reader.GetInt32(reader.GetOrdinal("FundPoolId")),
                    FundPoolCode          = S(reader, "FundPoolCode"),
                    FundPoolName          = S(reader, "FundPoolName"),
                    Status                = S(reader, "Status"),
                    CurrentBalance        = D(reader, "CurrentBalance"),
                    TotalIncome           = D(reader, "TotalIncome"),
                    TotalExpense          = D(reader, "TotalExpense"),
                    TotalPaymentsReceived = D(reader, "TotalPaymentsReceived"),
                    NetAmount             = D(reader, "NetAmount"),
                    BufferTotalAmount     = D(reader, "BufferTotalAmount"),
                });
            }
        }

        // ── Result Set 3: Transactions (only when single fund pool) ──
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                response.Transactions.Add(new FundPoolTxnRow
                {
                    TxnType   = S(reader, "TxnType"),
                    TxnDate   = reader.GetDateTime(reader.GetOrdinal("TxnDate")),
                    Amount    = D(reader, "Amount"),
                    Head      = S(reader, "Head"),
                    Mode      = S(reader, "Mode"),
                    CampName  = S(reader, "CampName"),
                    Purpose   = S(reader, "Purpose"),
                    VoucherNo = S(reader, "VoucherNo"),
                    CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                });
            }
        }

        await reader.CloseAsync();

        int totalRecords = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        response.TotalRecords = totalRecords;

        // Build summary from rows
        response.Summary = new FundPoolReportSummary
        {
            TotalFundPools  = totalRecords,
            ActiveFundPools = response.Rows.Count(r => r.Status == "Active"),
            TotalBalance    = response.Rows.Sum(r => r.CurrentBalance),
            TotalIncome     = response.Rows.Sum(r => r.TotalIncome),
            TotalExpense    = response.Rows.Sum(r => r.TotalExpense),
            TotalPayments   = response.Rows.Sum(r => r.TotalPaymentsReceived),
        };

        return Ok(ApiResponse<FundPoolReportResponse>.Ok(
            response,
            "Fund pool report retrieved successfully.",
            PaginationHelper.Build(totalRecords, request.ResolvedPageNumber,
                request.ResolvedPageSize == int.MaxValue ? 1000 : request.ResolvedPageSize)));
    }

    private static string  S(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? "" : r.GetString(o); } catch { return ""; } }
    private static decimal D(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? 0m : r.GetDecimal(o); } catch { return 0m; } }
}
