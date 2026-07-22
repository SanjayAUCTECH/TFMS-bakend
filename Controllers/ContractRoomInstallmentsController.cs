using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContractRoomInstallmentsController : ControllerBase
{
    private readonly IDbConnectionFactory _factory;
    public ContractRoomInstallmentsController(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// GET api/contractroominstallments/{contractId}
    /// Payment section — ContractRoomInstallments data
    /// contractId = compulsory | campId, roomId, month, status = optional
    /// </summary>
    [HttpGet("{contractId}")]
    public async Task<IActionResult> GetByContract(
        string contractId,
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
        cmd.Parameters.AddWithValue("@ContractId", contractId);
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
            $"Room installments for {contractId} retrieved."));
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
        return Ok(ApiResponse<object>.Ok(null, $"Room installments regenerated for {contractId}."));
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
