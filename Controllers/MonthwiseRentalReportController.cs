using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MonthwiseRentalReportController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;

    public MonthwiseRentalReportController(IDbConnectionFactory factory, IActivityLogService log)
    {
        _factory = factory;
        _activityLog = log;
    }

    /// <summary>
    /// GET api/monthwiserentalreport/test
    /// Test endpoint to verify API is working
    /// </summary>
    [HttpGet("test")]
    public IActionResult Test()
    {
        return Ok(ApiResponse<object>.Ok(
            new { 
                message = "Month-wise Rental Report API is working!",
                version = "1.0.0",
                timestamp = DateTime.Now,
                endpoints = new[] {
                    "GET /api/monthwiserentalreport",
                    "GET /api/monthwiserentalreport/summary",
                    "GET /api/monthwiserentalreport/export"
                }
            },
            "API test successful."
        ));
    }

    /// <summary>
    /// GET api/monthwiserentalreport
    /// Month-wise Rental Report from ContractRoomInstallments
    /// Filters: month, campId, tenantId, roomId, status
    /// Pagination: pageNumber, pageSize
    /// Sorting: sortBy (default: DueDate), sortDirection (ASC/DESC)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetMonthwiseRentalReport(
        [FromQuery] string? month = null,
        [FromQuery] int? campId = null,
        [FromQuery] int? tenantId = null,
        [FromQuery] int? roomId = null,
        [FromQuery] string? status = null,
        [FromQuery] string? contractStatus = null,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 50,
        [FromQuery] string? sortBy = "DueDate",
        [FromQuery] string? sortDirection = "ASC")
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetMonthwiseRentalReport", conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120 // 2 minutes for large reports
        };

        // Add parameters
        cmd.Parameters.AddWithValue("@Month", (object?)month ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId", (object?)campId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId", (object?)tenantId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomId", (object?)roomId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractStatus", (object?)contractStatus ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FromDate", (object?)fromDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate", (object?)toDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", pageNumber);
        cmd.Parameters.AddWithValue("@PageSize", pageSize);
        cmd.Parameters.AddWithValue("@SortBy", sortBy ?? "DueDate");
        cmd.Parameters.AddWithValue("@SortDirection", sortDirection?.ToUpper() == "DESC" ? "DESC" : "ASC");

        // Output parameter for total records
        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var reportData = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();

        while (await rd.ReadAsync())
        {
            reportData.Add(new
            {
                id = rd.IsDBNull(rd.GetOrdinal("Id")) ? (int?)null : rd.GetInt32(rd.GetOrdinal("Id")),
                contractId = rd.IsDBNull(rd.GetOrdinal("ContractId")) ? null : rd.GetString(rd.GetOrdinal("ContractId")),
                roomStatus = rd.GetString(rd.GetOrdinal("RoomStatus")), // NEW: Occupied or Vacant
                
                // Contract Details
                contractType = rd.IsDBNull(rd.GetOrdinal("ContractType")) ? null : rd.GetString(rd.GetOrdinal("ContractType")),
                contractStatus = rd.IsDBNull(rd.GetOrdinal("ContractStatus")) ? null : rd.GetString(rd.GetOrdinal("ContractStatus")),
                installmentType = rd.IsDBNull(rd.GetOrdinal("InstallmentType")) ? null : rd.GetString(rd.GetOrdinal("InstallmentType")),
                startDate = rd.IsDBNull(rd.GetOrdinal("StartDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("StartDate")),
                endDate = rd.IsDBNull(rd.GetOrdinal("EndDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("EndDate")),
                
                // Tenant Details
                tenantId = rd.IsDBNull(rd.GetOrdinal("TenantId")) ? (int?)null : rd.GetInt32(rd.GetOrdinal("TenantId")),
                tenantName = rd.IsDBNull(rd.GetOrdinal("TenantName")) ? "N/A" : rd.GetString(rd.GetOrdinal("TenantName")),
                tenantContact = rd.IsDBNull(rd.GetOrdinal("TenantContact")) ? null : rd.GetString(rd.GetOrdinal("TenantContact")),
                tenantEmail = rd.IsDBNull(rd.GetOrdinal("TenantEmail")) ? null : rd.GetString(rd.GetOrdinal("TenantEmail")),
                
                // Camp Details
                campId = rd.GetInt32(rd.GetOrdinal("CampId")),
                campName = rd.GetString(rd.GetOrdinal("CampName")),
                campLocation = rd.IsDBNull(rd.GetOrdinal("CampLocation")) ? null : rd.GetString(rd.GetOrdinal("CampLocation")),
                
                // Room Details
                roomId = rd.GetInt32(rd.GetOrdinal("RoomId")),
                roomNo = rd.GetString(rd.GetOrdinal("RoomNo")),
                floorName = rd.IsDBNull(rd.GetOrdinal("FloorName")) ? null : rd.GetString(rd.GetOrdinal("FloorName")),
                
                // Installment Details
                installmentNo = rd.IsDBNull(rd.GetOrdinal("InstallmentNo")) ? 0 : rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                month = rd.IsDBNull(rd.GetOrdinal("Month")) ? null : rd.GetString(rd.GetOrdinal("Month")),
                dueDate = rd.IsDBNull(rd.GetOrdinal("DueDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("DueDate")),
                installAmount = rd.GetDecimal(rd.GetOrdinal("InstallAmount")),
                
                // Payment Details
                paymentMode = rd.IsDBNull(rd.GetOrdinal("PaymentMode")) ? "N/A" : rd.GetString(rd.GetOrdinal("PaymentMode")),
                referenceNo = rd.IsDBNull(rd.GetOrdinal("ReferenceNo")) ? "N/A" : rd.GetString(rd.GetOrdinal("ReferenceNo")),
                clearanceDate = rd.IsDBNull(rd.GetOrdinal("ClearanceDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("ClearanceDate")),
                paidDate = rd.IsDBNull(rd.GetOrdinal("PaidDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("PaidDate")),
                paidAmount = rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                balance = rd.GetDecimal(rd.GetOrdinal("Balance")),
                status = rd.GetString(rd.GetOrdinal("Status")),
                
                // SD (Security Deposit) Details
                sdAmount = rd.IsDBNull(rd.GetOrdinal("SdAmount")) ? (decimal?)null : rd.GetDecimal(rd.GetOrdinal("SdAmount")),
                sdDate = rd.IsDBNull(rd.GetOrdinal("SdDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("SdDate")),
                
                // Timestamps
                createdAt = rd.GetDateTime(rd.GetOrdinal("CreatedAt")),
                updatedAt = rd.GetDateTime(rd.GetOrdinal("UpdatedAt"))
            });
        }

        await rd.CloseAsync();

        // Get total records from OUTPUT parameter
        int totalRecords = (int)(totalParam.Value ?? 0);

        // Calculate summary statistics (use decimal for monetary values)
        var totalInstallAmount = reportData.Sum(r => (decimal)((dynamic)r).installAmount);
        var totalPaidAmount = reportData.Sum(r => (decimal)((dynamic)r).paidAmount);
        var totalBalance = reportData.Sum(r => (decimal)((dynamic)r).balance);

        var summary = new
        {
            totalRecords = totalRecords,
            currentPageRecords = reportData.Count,
            totalInstallAmount = totalInstallAmount,
            totalPaidAmount = totalPaidAmount,
            totalBalance = totalBalance,
            filterApplied = new
            {
                month = month ?? "All",
                campId = campId?.ToString() ?? "All",
                tenantId = tenantId?.ToString() ?? "All",
                roomId = roomId?.ToString() ?? "All",
                status = status ?? "All",
                contractStatus = contractStatus ?? "All",
                dateRange = fromDate != null || toDate != null
                    ? $"{fromDate?.ToString("yyyy-MM-dd") ?? "Start"} to {toDate?.ToString("yyyy-MM-dd") ?? "End"}"
                    : "All"
            }
        };

        var pagination = PaginationHelper.Build(totalRecords, pageNumber, pageSize);

        var message = month != null
            ? $"Month-wise rental report for {month} retrieved successfully."
            : "Month-wise rental report retrieved successfully.";

        return Ok(ApiResponse<object>.Ok(
            new
            {
                summary,
                reportData,
                totalRecords
            },
            message,
            pagination: pagination
        ));
    }

    /// <summary>
    /// GET api/monthwiserentalreport/summary
    /// Get aggregated summary by month
    /// </summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetMonthlySummary(
        [FromQuery] int? campId = null,
        [FromQuery] int? tenantId = null,
        [FromQuery] string? status = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetMonthwiseRentalSummary", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@CampId", (object?)campId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId", (object?)tenantId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);

        var summaryData = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();

        while (await rd.ReadAsync())
        {
            summaryData.Add(new
            {
                month = rd.GetString(rd.GetOrdinal("Month")),
                totalRooms = rd.GetInt32(rd.GetOrdinal("TotalRooms")),
                totalInstallments = rd.GetInt32(rd.GetOrdinal("TotalInstallments")),
                totalInstallAmount = rd.GetDecimal(rd.GetOrdinal("TotalInstallAmount")),
                totalPaidAmount = rd.GetDecimal(rd.GetOrdinal("TotalPaidAmount")),
                totalBalance = rd.GetDecimal(rd.GetOrdinal("TotalBalance")),
                paidCount = rd.GetInt32(rd.GetOrdinal("PaidCount")),
                pendingCount = rd.GetInt32(rd.GetOrdinal("PendingCount")),
                partialCount = rd.GetInt32(rd.GetOrdinal("PartialCount")),
                overdueCount = rd.GetInt32(rd.GetOrdinal("OverdueCount"))
            });
        }

        return Ok(ApiResponse<object>.Ok(
            new { summaryData, totalRecords = summaryData.Count },
            "Monthly summary retrieved successfully."
        ));
    }

    /// <summary>
    /// GET api/monthwiserentalreport/export
    /// Export report data (returns all records without pagination for export)
    /// </summary>
    [HttpGet("export")]
    public async Task<IActionResult> ExportReport(
        [FromQuery] string? month = null,
        [FromQuery] int? campId = null,
        [FromQuery] int? tenantId = null,
        [FromQuery] int? roomId = null,
        [FromQuery] string? status = null,
        [FromQuery] string? contractStatus = null,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetMonthwiseRentalReport", conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300 // 5 minutes for large exports
        };

        // Add parameters - use max values for export
        cmd.Parameters.AddWithValue("@Month", (object?)month ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId", (object?)campId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TenantId", (object?)tenantId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomId", (object?)roomId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ContractStatus", (object?)contractStatus ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FromDate", (object?)fromDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate", (object?)toDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", 1);
        cmd.Parameters.AddWithValue("@PageSize", int.MaxValue); // Get all records
        cmd.Parameters.AddWithValue("@SortBy", "DueDate");
        cmd.Parameters.AddWithValue("@SortDirection", "ASC");

        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var exportData = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();

        while (await rd.ReadAsync())
        {
            exportData.Add(new
            {
                contractId = rd.GetString(rd.GetOrdinal("ContractId")),
                contractType = rd.GetString(rd.GetOrdinal("ContractType")),
                contractStatus = rd.GetString(rd.GetOrdinal("ContractStatus")),
                tenantName = rd.GetString(rd.GetOrdinal("TenantName")),
                tenantContact = rd.IsDBNull(rd.GetOrdinal("TenantContact")) ? "" : rd.GetString(rd.GetOrdinal("TenantContact")),
                tenantEmail = rd.IsDBNull(rd.GetOrdinal("TenantEmail")) ? "" : rd.GetString(rd.GetOrdinal("TenantEmail")),
                campName = rd.GetString(rd.GetOrdinal("CampName")),
                campLocation = rd.IsDBNull(rd.GetOrdinal("CampLocation")) ? "" : rd.GetString(rd.GetOrdinal("CampLocation")),
                roomNo = rd.GetString(rd.GetOrdinal("RoomNo")),
                floorName = rd.IsDBNull(rd.GetOrdinal("FloorName")) ? "" : rd.GetString(rd.GetOrdinal("FloorName")),
                month = rd.GetString(rd.GetOrdinal("Month")),
                dueDate = rd.GetDateTime(rd.GetOrdinal("DueDate")).ToString("yyyy-MM-dd"),
                installAmount = rd.GetDecimal(rd.GetOrdinal("InstallAmount")),
                paidAmount = rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                balance = rd.GetDecimal(rd.GetOrdinal("Balance")),
                status = rd.GetString(rd.GetOrdinal("Status")),
                paymentMode = rd.GetString(rd.GetOrdinal("PaymentMode")),
                referenceNo = rd.GetString(rd.GetOrdinal("ReferenceNo")),
                paidDate = rd.IsDBNull(rd.GetOrdinal("PaidDate")) ? "" : rd.GetDateTime(rd.GetOrdinal("PaidDate")).ToString("yyyy-MM-dd"),
                sdAmount = rd.IsDBNull(rd.GetOrdinal("SdAmount")) ? (decimal?)null : rd.GetDecimal(rd.GetOrdinal("SdAmount")),
                sdDate = rd.IsDBNull(rd.GetOrdinal("SdDate")) ? "" : rd.GetDateTime(rd.GetOrdinal("SdDate")).ToString("yyyy-MM-dd")
            });
        }

        await rd.CloseAsync();
        int totalRecords = (int)(totalParam.Value ?? 0);

        await Log(ActivityType.View, ActivityModule.Reports,
            $"Exported Month-wise Rental Report: {totalRecords} records, Month: {month ?? "All"}, Camp: {campId?.ToString() ?? "All"}",
            null, "MonthwiseRentalReport");

        return Ok(ApiResponse<object>.Ok(
            new { exportData, totalRecords },
            $"Export data retrieved successfully - {totalRecords} records."
        ));
    }
}
