using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Claims;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AdvanceApprovalController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;

    public AdvanceApprovalController(IDbConnectionFactory factory, IActivityLogService log)
    {
        _factory     = factory;
        _activityLog = log;
    }

    /// <summary>
    /// GET api/AdvanceApproval/advanced-months
    /// Returns distinct months list from ContractRoomInstallments
    /// where Status IN ('Advanced','AdvancedPartial').
    /// Optional filters: campId, contractId
    /// </summary>
    [HttpGet("advanced-months")]
    public async Task<IActionResult> GetAdvancedMonths(
        [FromQuery] int?    campId     = null,
        [FromQuery] string? contractId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var where = new List<string>
        {
            "ISNULL(cri.IsDeleted,0) = 0",
            "cri.Status IN ('Advanced','AdvancedPartial')"
        };
        var cmd = new SqlCommand("", conn);

        if (campId.HasValue)
        {
            where.Add("cri.CampId = @CampId");
            cmd.Parameters.AddWithValue("@CampId", campId.Value);
        }
        if (!string.IsNullOrEmpty(contractId))
        {
            where.Add("cri.ContractId = @ContractId");
            cmd.Parameters.AddWithValue("@ContractId", contractId);
        }

        cmd.CommandText = $@"
            SELECT
                cri.Month,
                COUNT(*)              AS TotalRecords,
                SUM(cri.PaidAmount)   AS TotalPaidAmount,
                SUM(cri.InstallAmount)AS TotalInstallAmount,
                MIN(cri.DueDate)      AS FromDueDate,
                MAX(cri.DueDate)      AS ToDueDate,
                COUNT(DISTINCT cri.ContractId) AS TotalContracts,
                COUNT(DISTINCT cri.CampId)     AS TotalCamps
            FROM ContractRoomInstallments cri
            WHERE {string.Join(" AND ", where)}
            GROUP BY cri.Month
            ORDER BY MIN(cri.DueDate)";

        var months = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync())
        {
            months.Add(new
            {
                month              = rd.IsDBNull(rd.GetOrdinal("Month"))             ? "" : rd.GetString(rd.GetOrdinal("Month")),
                totalRecords       = rd.GetInt32(rd.GetOrdinal("TotalRecords")),
                totalPaidAmount    = rd.IsDBNull(rd.GetOrdinal("TotalPaidAmount"))   ? 0m : rd.GetDecimal(rd.GetOrdinal("TotalPaidAmount")),
                totalInstallAmount = rd.IsDBNull(rd.GetOrdinal("TotalInstallAmount"))? 0m : rd.GetDecimal(rd.GetOrdinal("TotalInstallAmount")),
                fromDueDate        = rd.IsDBNull(rd.GetOrdinal("FromDueDate"))       ? null : (DateTime?)rd.GetDateTime(rd.GetOrdinal("FromDueDate")),
                toDueDate          = rd.IsDBNull(rd.GetOrdinal("ToDueDate"))         ? null : (DateTime?)rd.GetDateTime(rd.GetOrdinal("ToDueDate")),
                totalContracts     = rd.GetInt32(rd.GetOrdinal("TotalContracts")),
                totalCamps         = rd.GetInt32(rd.GetOrdinal("TotalCamps")),
            });
        }

        return Ok(ApiResponse<object>.Ok(new
        {
            totalMonths = months.Count,
            months
        }, $"{months.Count} month(s) with advanced payments found."));
    }

    /// <summary>
    /// GET api/AdvanceApproval/pending?month=Jul26&amp;campId=1&amp;contractId=CNT-0001
    /// Returns all Advanced/AdvancedPartial installments for the selected month.
    /// Filters: month (required), campId, contractId, roomId
    /// </summary>
    [HttpGet("pending")]
    public async Task<IActionResult> GetPending(
        [FromQuery] string  month,
        [FromQuery] int?    campId     = null,
        [FromQuery] string? contractId = null,
        [FromQuery] int?    roomId     = null)
    {
        if (string.IsNullOrWhiteSpace(month))
            return BadRequest(ApiResponse<object>.Fail("Month is required. Format: Jul26"));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var where = new List<string>
        {
            "ISNULL(cri.IsDeleted,0)=0",
            "cri.Status IN ('Advanced','AdvancedPartial')",
            "cri.Month = @Month"
        };
        var cmd = new SqlCommand("", conn);
        cmd.Parameters.AddWithValue("@Month", month);

        if (campId.HasValue)
        {
            where.Add("cri.CampId = @CampId");
            cmd.Parameters.AddWithValue("@CampId", campId.Value);
        }
        if (!string.IsNullOrEmpty(contractId))
        {
            where.Add("cri.ContractId = @ContractId");
            cmd.Parameters.AddWithValue("@ContractId", contractId);
        }
        if (roomId.HasValue)
        {
            where.Add("cri.RoomId = @RoomId");
            cmd.Parameters.AddWithValue("@RoomId", roomId.Value);
        }

        cmd.CommandText = $@"
            SELECT
                cri.Id            AS CriId,
                cri.ContractId,
                cri.CampId,
                cri.CampName,
                cri.RoomId,
                cri.RoomNo,
                cri.InstallmentNo,
                cri.Month,
                cri.InstallAmount,
                cri.PaidAmount,
                cri.Status,
                cri.PaidDate,
                t.Name            AS TenantName
            FROM ContractRoomInstallments cri
            JOIN Contracts ct ON ct.ContractId = cri.ContractId AND ct.IsDeleted = 0
            JOIN Tenants   t  ON t.Id = ct.TenantId AND t.IsDeleted = 0
            WHERE {string.Join(" AND ", where)}
            ORDER BY cri.ContractId, cri.CampId, cri.RoomId, cri.InstallmentNo";

        var rows = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync())
        {
            rows.Add(new
            {
                criId         = rd.GetInt32(rd.GetOrdinal("CriId")),
                contractId    = rd.IsDBNull(rd.GetOrdinal("ContractId"))  ? "" : rd.GetString(rd.GetOrdinal("ContractId")),
                campId        = rd.GetInt32(rd.GetOrdinal("CampId")),
                campName      = rd.IsDBNull(rd.GetOrdinal("CampName"))    ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                roomId        = rd.GetInt32(rd.GetOrdinal("RoomId")),
                roomNo        = rd.IsDBNull(rd.GetOrdinal("RoomNo"))      ? "" : rd.GetString(rd.GetOrdinal("RoomNo")),
                installmentNo = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                month         = rd.IsDBNull(rd.GetOrdinal("Month"))       ? "" : rd.GetString(rd.GetOrdinal("Month")),
                installAmount = rd.IsDBNull(rd.GetOrdinal("InstallAmount"))? 0m : rd.GetDecimal(rd.GetOrdinal("InstallAmount")),
                paidAmount    = rd.IsDBNull(rd.GetOrdinal("PaidAmount"))  ? 0m : rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                status        = rd.IsDBNull(rd.GetOrdinal("Status"))      ? "" : rd.GetString(rd.GetOrdinal("Status")),
                paidDate      = rd.IsDBNull(rd.GetOrdinal("PaidDate"))    ? null : (DateTime?)rd.GetDateTime(rd.GetOrdinal("PaidDate")),
                tenantName    = rd.IsDBNull(rd.GetOrdinal("TenantName"))  ? "" : rd.GetString(rd.GetOrdinal("TenantName")),
            });
        }

        return Ok(ApiResponse<object>.Ok(new
        {
            month        = month,
            totalPending = rows.Count,
            rows         = rows
        }, $"{rows.Count} advanced payment(s) pending approval for {month}."));
    }

    /// <summary>
    /// POST api/AdvanceApproval/approve
    /// Approves Advanced → Paid, AdvancedPartial → PaidPartial
    /// for the selected month. Updates PaidDate and TxnDate to PaymentDate.
    /// </summary>
    [HttpPost("approve")]
    public async Task<IActionResult> Approve([FromBody] ApproveAdvancePaymentRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (string.IsNullOrWhiteSpace(request.Month))
            return BadRequest(ApiResponse<object>.Fail("Month is required. Format: Jul26"));

        if (request.PaymentDate == default)
            return BadRequest(ApiResponse<object>.Fail("PaymentDate is required."));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_ApproveAdvancePayments", conn)
        {
            CommandType    = CommandType.StoredProcedure,
            CommandTimeout = 60
        };

        cmd.Parameters.AddWithValue("@PaymentDate", request.PaymentDate.Date);
        cmd.Parameters.AddWithValue("@Month",       request.Month.Trim());
        cmd.Parameters.AddWithValue("@ContractId",  (object?)request.ContractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",      (object?)request.CampId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomId",      (object?)request.RoomId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ApprovedBy",  CurrentUserId == 0 ? DBNull.Value : (object)CurrentUserId);

        var updatedCountParam = new SqlParameter("@UpdatedCount", SqlDbType.Int)
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(updatedCountParam);

        var updatedRows = new List<ApprovedInstallmentRow>();
        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            while (await rd.ReadAsync())
            {
                updatedRows.Add(new ApprovedInstallmentRow
                {
                    CriId         = rd.IsDBNull(rd.GetOrdinal("CriId"))         ? 0  : rd.GetInt32(rd.GetOrdinal("CriId")),
                    ContractId    = rd.IsDBNull(rd.GetOrdinal("ContractId"))    ? "" : rd.GetString(rd.GetOrdinal("ContractId")),
                    CampId        = rd.IsDBNull(rd.GetOrdinal("CampId"))        ? 0  : rd.GetInt32(rd.GetOrdinal("CampId")),
                    CampName      = rd.IsDBNull(rd.GetOrdinal("CampName"))      ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                    RoomId        = rd.IsDBNull(rd.GetOrdinal("RoomId"))        ? 0  : rd.GetInt32(rd.GetOrdinal("RoomId")),
                    RoomNo        = rd.IsDBNull(rd.GetOrdinal("RoomNo"))        ? "" : rd.GetString(rd.GetOrdinal("RoomNo")),
                    InstallmentNo = rd.IsDBNull(rd.GetOrdinal("InstallmentNo")) ? 0  : rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                    Month         = rd.IsDBNull(rd.GetOrdinal("Month"))         ? "" : rd.GetString(rd.GetOrdinal("Month")),
                    InstallAmount = rd.IsDBNull(rd.GetOrdinal("InstallAmount")) ? 0m : rd.GetDecimal(rd.GetOrdinal("InstallAmount")),
                    PaidAmount    = rd.IsDBNull(rd.GetOrdinal("PaidAmount"))    ? 0m : rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                    NewStatus     = rd.IsDBNull(rd.GetOrdinal("NewStatus"))     ? "" : rd.GetString(rd.GetOrdinal("NewStatus")),
                    NewPaidDate   = rd.IsDBNull(rd.GetOrdinal("NewPaidDate"))   ? default : rd.GetDateTime(rd.GetOrdinal("NewPaidDate")),
                });
            }
        }

        int updatedCount = updatedCountParam.Value == DBNull.Value ? 0 : (int)updatedCountParam.Value;

        if (updatedCount == 0)
            return Ok(ApiResponse<ApproveAdvancePaymentResponse>.Ok(
                new ApproveAdvancePaymentResponse
                {
                    UpdatedCount = 0,
                    Month        = request.Month,
                    PaymentDate  = request.PaymentDate.ToString("yyyy-MM-dd"),
                    UpdatedRows  = new()
                },
                $"No Advanced/AdvancedPartial records found for month '{request.Month}'."));

        // Activity log
        await Log(
            ActivityType.Approve,
            ActivityModule.ContractRoomInstallments,
            $"Approved {updatedCount} advance payment(s) for month '{request.Month}' with PaymentDate {request.PaymentDate:yyyy-MM-dd}",
            request.Month,
            "ContractRoomInstallments");

        return Ok(ApiResponse<ApproveAdvancePaymentResponse>.Ok(
            new ApproveAdvancePaymentResponse
            {
                UpdatedCount = updatedCount,
                Month        = request.Month,
                PaymentDate  = request.PaymentDate.ToString("yyyy-MM-dd"),
                UpdatedRows  = updatedRows
            },
            $"{updatedCount} advanced payment(s) approved successfully for month '{request.Month}'."));
    }
}
