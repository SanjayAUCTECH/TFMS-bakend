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
public class ContractRoomInstallmentsController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;
    public ContractRoomInstallmentsController(IDbConnectionFactory factory, IActivityLogService log)
    {
        _factory     = factory;
        _activityLog = log;
    }

    /// <summary>
    /// GET api/contractroominstallments
    /// Payment section — ContractRoomInstallments data
    /// All parameters optional: contractId, campId, roomId, month, status
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetByContract(
        [FromQuery] string? contractId = null,
        [FromQuery] int?    campId = null,
        [FromQuery] int?    roomId = null,
        [FromQuery] string? month  = null,
        [FromQuery] string? status = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetContractRoomInstallments", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ContractId", (object?)contractId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",     (object?)campId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomId",     (object?)roomId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month",      (object?)month  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",     (object?)status ?? DBNull.Value);

        var rows = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync())
        {
            rows.Add(new
            {
                id            = rd.GetInt32(rd.GetOrdinal("Id")),
                contractId    = rd.GetString(rd.GetOrdinal("ContractId")),
                campId        = rd.GetInt32(rd.GetOrdinal("CampId")),
                campName      = rd.GetString(rd.GetOrdinal("CampName")),
                roomId        = rd.GetInt32(rd.GetOrdinal("RoomId")),
                roomNo        = rd.GetString(rd.GetOrdinal("RoomNo")),
                installmentNo = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                installAmount = rd.GetDecimal(rd.GetOrdinal("InstallAmount")),
                dueDate       = rd.GetDateTime(rd.GetOrdinal("DueDate")),
                month         = rd.GetString(rd.GetOrdinal("Month")),
                paymentMode   = rd.GetString(rd.GetOrdinal("PaymentMode")),
                referenceNo   = rd.GetString(rd.GetOrdinal("ReferenceNo")),
                clearanceDate = rd.IsDBNull(rd.GetOrdinal("ClearanceDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("ClearanceDate")),
                status        = rd.GetString(rd.GetOrdinal("Status")),
                paidAmount    = rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                balance       = rd.GetDecimal(rd.GetOrdinal("Balance")),
                paidDate      = rd.IsDBNull(rd.GetOrdinal("PaidDate")) ? (DateTime?)null : rd.GetDateTime(rd.GetOrdinal("PaidDate")),
                createdAt     = rd.GetDateTime(rd.GetOrdinal("CreatedAt")),
                updatedAt     = rd.GetDateTime(rd.GetOrdinal("UpdatedAt")),
            });
        }

        return Ok(ApiResponse<object>.Ok(new { rows, totalRecords = rows.Count },
            string.IsNullOrEmpty(contractId) 
                ? "Room installments retrieved." 
                : $"Room installments for {contractId} retrieved."));
    }

    /// <summary>
    /// GET api/contractroominstallments/{contractId}/months
    /// Returns all unique months for a contract (contractId required)
    /// e.g. [{month:"Dec26", dueDate:"2026-12-01", installmentNo:1}, ...]
    /// </summary>
    [HttpGet("{contractId}/months")]
    public async Task<IActionResult> GetMonths(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetContractRoomInstallmentMonths", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ContractId", contractId);

        var months = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync())
        {
            months.Add(new
            {
                month         = rd.GetString(rd.GetOrdinal("Month")),
                dueDate       = rd.GetDateTime(rd.GetOrdinal("DueDate")),
                installmentNo = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
            });
        }

        return Ok(ApiResponse<object>.Ok(new { months, totalRecords = months.Count },
            $"Months for contract {contractId} retrieved."));
    }

    /// <summary>PATCH api/contractroominstallments/{id} — update payment info</summary>
    [HttpPatch("{id:int}")]
    public async Task<IActionResult> UpdatePayment(int id, [FromBody] UpdateRoomInstallmentRequest req)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_UpdateContractRoomInstallment", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Id",            id);
        cmd.Parameters.AddWithValue("@PaymentMode",   (object?)req.PaymentMode   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ReferenceNo",   (object?)req.ReferenceNo   ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ClearanceDate", (object?)req.ClearanceDate ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaidAmount",    (object?)req.PaidAmount    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PaidDate",      (object?)req.PaidDate      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Status",        (object?)req.Status        ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();

        await Log(ActivityType.Update, ActivityModule.ContractRoomInstallments,
            $"Updated Room Installment #{id}, Status: {req.Status ?? "N/A"}, PaidAmount: {req.PaidAmount?.ToString() ?? "N/A"}",
            id.ToString(), "ContractRoomInstallment");

        return Ok(ApiResponse<object>.Ok(new { id }, "Room installment updated."));
    }

    /// <summary>POST api/contractroominstallments/regenerate/{contractId}</summary>
    [HttpPost("regenerate/{contractId}")]
    public async Task<IActionResult> Regenerate(string contractId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GenerateContractRoomInstallments", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        await cmd.ExecuteNonQueryAsync();

        await Log(ActivityType.Update, ActivityModule.ContractRoomInstallments,
            $"Regenerated Room Installments for Contract {contractId}",
            contractId, "ContractRoomInstallment");

        return Ok(ApiResponse<object?>.Ok(null, $"Room installments regenerated for {contractId}."));
    }

    /// <summary>
    /// GET api/contractroominstallments/monthwise-occupied
    /// Get month-wise occupied rooms from ContractRoomInstallments
    /// Filters: campId (optional), month (optional), PageNumber, PageSize
    /// Only includes rooms from Active or Completed contracts
    /// Uses stored procedure: sp_GetMonthwiseOccupiedRooms
    /// </summary>
    [HttpGet("monthwise-occupied")]
    public async Task<IActionResult> GetMonthwiseOccupiedRooms(
        [FromQuery] int? campId = null,
        [FromQuery] string? month = null,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Call stored procedure
        await using var cmd = new SqlCommand("sp_GetMonthwiseOccupiedRooms", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        
        cmd.Parameters.AddWithValue("@CampId", (object?)campId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month", (object?)month ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", pageNumber);
        cmd.Parameters.AddWithValue("@PageSize", pageSize);
        
        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var occupiedRooms = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync())
        {
            occupiedRooms.Add(new
            {
                id                 = rd.GetInt32(rd.GetOrdinal("Id")),
                contractId         = rd.GetString(rd.GetOrdinal("ContractId")),
                campId             = rd.GetInt32(rd.GetOrdinal("CampId")),
                campName           = rd.GetString(rd.GetOrdinal("CampName")),
                roomId             = rd.GetInt32(rd.GetOrdinal("RoomId")),
                roomNo             = rd.GetString(rd.GetOrdinal("RoomNo")),
                month              = rd.GetString(rd.GetOrdinal("Month")),
                dueDate            = rd.GetDateTime(rd.GetOrdinal("DueDate")),
                installmentNo      = rd.GetInt32(rd.GetOrdinal("InstallmentNo")),
                installAmount      = rd.GetDecimal(rd.GetOrdinal("InstallAmount")),
                installmentStatus  = rd.GetString(rd.GetOrdinal("InstallmentStatus")),
                paidAmount         = rd.GetDecimal(rd.GetOrdinal("PaidAmount")),
                balance            = rd.GetDecimal(rd.GetOrdinal("Balance")),
                contractStatus     = rd.GetString(rd.GetOrdinal("ContractStatus")),
                tenantId           = rd.GetInt32(rd.GetOrdinal("TenantId")),
                startDate          = rd.GetDateTime(rd.GetOrdinal("StartDate")),
                endDate            = rd.GetDateTime(rd.GetOrdinal("EndDate")),
                contractType       = rd.GetString(rd.GetOrdinal("ContractType"))
            });
        }
        
        await rd.CloseAsync();
        
        // Get total records from OUTPUT parameter
        int totalRecords = (int)(totalParam.Value ?? 0);

        // Calculate total pages
        int totalPages = (int)Math.Ceiling((double)totalRecords / pageSize);

        // Get summary statistics (from all data, not just current page)
        var uniqueRooms = occupiedRooms
            .Select(r => new { 
                campId = ((dynamic)r).campId, 
                roomId = ((dynamic)r).roomId 
            })
            .Distinct()
            .Count();

        var summary = new
        {
            month = month ?? "All",
            totalOccupiedRooms = totalRecords,
            uniqueOccupiedRooms = uniqueRooms,
            currentPageRecords = occupiedRooms.Count,
            message = month != null 
                ? $"All rooms in ContractRoomInstallments for {month} are occupied"
                : "All occupied rooms from Active/Completed contracts"
        };

        var pagination = new
        {
            pageNumber = pageNumber,
            pageSize = pageSize,
            totalRecords = totalRecords,
            totalPages = totalPages,
            hasNextPage = pageNumber < totalPages,
            hasPreviousPage = pageNumber > 1
        };

        var message = month != null 
            ? $"Month-wise occupied rooms retrieved for {month}."
            : "All occupied rooms retrieved.";

        return Ok(ApiResponse<object>.Ok(
            new { 
                summary, 
                occupiedRooms, 
                totalRecords = totalRecords 
            },
            message,
            pagination: PaginationHelper.Build(totalRecords, pageNumber, pageSize)));
    }

    /// <summary>
    /// GET api/contractroominstallments/monthwise-vacant
    /// Get month-wise vacant/empty rooms
    /// Returns rooms that are NOT in ContractRoomInstallments for the specified month
    /// Filters: campId (optional), month (optional), PageNumber, PageSize
    /// Uses stored procedure: sp_GetMonthwiseVacantRooms
    /// </summary>
    [HttpGet("monthwise-vacant")]
    public async Task<IActionResult> GetMonthwiseVacantRooms(
        [FromQuery] int? campId = null,
        [FromQuery] string? month = null,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Call stored procedure
        await using var cmd = new SqlCommand("sp_GetMonthwiseVacantRooms", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        
        cmd.Parameters.AddWithValue("@CampId", (object?)campId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Month", (object?)month ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", pageNumber);
        cmd.Parameters.AddWithValue("@PageSize", pageSize);
        
        var totalParam = new SqlParameter("@TotalRecords", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        cmd.Parameters.Add(totalParam);

        var vacantRooms = new List<object>();
        await using var rd = await cmd.ExecuteReaderAsync();
        while (await rd.ReadAsync())
        {
            vacantRooms.Add(new
            {
                roomId        = rd.GetInt32(rd.GetOrdinal("RoomId")),
                roomNo        = rd.IsDBNull(rd.GetOrdinal("RoomNo")) ? "" : rd.GetString(rd.GetOrdinal("RoomNo")),
                campId        = rd.IsDBNull(rd.GetOrdinal("CampId")) ? 0 : rd.GetInt32(rd.GetOrdinal("CampId")),
                campName      = rd.IsDBNull(rd.GetOrdinal("CampName")) ? "" : rd.GetString(rd.GetOrdinal("CampName")),
                floorId       = rd.IsDBNull(rd.GetOrdinal("FloorId")) ? (int?)null : rd.GetInt32(rd.GetOrdinal("FloorId")),
                floorName     = rd.IsDBNull(rd.GetOrdinal("FloorName")) ? "" : rd.GetString(rd.GetOrdinal("FloorName")),
                occupied      = rd.GetBoolean(rd.GetOrdinal("Occupied")),
                monthlyPrice  = rd.IsDBNull(rd.GetOrdinal("MonthlyPrice")) ? 0m : rd.GetDecimal(rd.GetOrdinal("MonthlyPrice")),
                roomStatus    = rd.IsDBNull(rd.GetOrdinal("RoomStatus")) ? "" : rd.GetString(rd.GetOrdinal("RoomStatus")),
                otherDetails  = rd.IsDBNull(rd.GetOrdinal("OtherDetails")) ? "" : rd.GetString(rd.GetOrdinal("OtherDetails"))
            });
        }
        
        await rd.CloseAsync();
        
        // Get total records from OUTPUT parameter
        int totalRecords = (int)(totalParam.Value ?? 0);

        // Calculate total pages
        int totalPages = (int)Math.Ceiling((double)totalRecords / pageSize);

        var summary = new
        {
            month = month ?? "All",
            totalVacantRooms = totalRecords,
            currentPageRecords = vacantRooms.Count,
            message = month != null 
                ? $"Vacant rooms for {month} (not in ContractRoomInstallments)"
                : "All vacant rooms (not in any active/completed contracts)"
        };

        var pagination = new
        {
            pageNumber = pageNumber,
            pageSize = pageSize,
            totalRecords = totalRecords,
            totalPages = totalPages,
            hasNextPage = pageNumber < totalPages,
            hasPreviousPage = pageNumber > 1
        };

        var message = month != null 
            ? $"Month-wise vacant rooms retrieved for {month}."
            : "All vacant rooms retrieved.";

        return Ok(ApiResponse<object>.Ok(
            new { 
                summary, 
                vacantRooms, 
                totalRecords = totalRecords 
            },
            message,
            pagination: PaginationHelper.Build(totalRecords, pageNumber, pageSize)));
    }
}

public class UpdateRoomInstallmentRequest
{
    public string?   PaymentMode   { get; set; }
    public string?   ReferenceNo   { get; set; }
    public DateTime? ClearanceDate { get; set; }
    public decimal?  PaidAmount    { get; set; }
    public DateTime? PaidDate      { get; set; }
    public string?   Status        { get; set; }
}
