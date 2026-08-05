using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CampCampbossesController : BaseApiController
{
    private readonly IDbConnectionFactory _factory;
    public CampCampbossesController(IDbConnectionFactory factory, IActivityLogService log)
    { _factory = factory; _activityLog = log; }

    /// <summary>
    /// GET /api/CampCampbosses?campId=1
    /// Get campbosses assigned to a camp (or all if no filter)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int? campId, [FromQuery] int? campbossId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            @"SELECT cc.Id, cc.CampId, ISNULL(c.Name,'') AS CampName,
                cc.CampbossId, ISNULL(cb.Name,'') AS CampbossName, ISNULL(cb.CampbossId,'') AS CampbossCode,
                ISNULL(cc.Type,'') AS Type, ISNULL(cc.Amount,0) AS Amount
            FROM CampCampbosses cc
            LEFT JOIN Camps c ON c.Id=cc.CampId AND c.IsDeleted=0
            LEFT JOIN Campbosses cb ON cb.Id=cc.CampbossId AND cb.IsDeleted=0
            WHERE ISNULL(cc.IsDeleted,0)=0
              AND (@CampId IS NULL OR cc.CampId=@CampId)
              AND (@CampbossId IS NULL OR cc.CampbossId=@CampbossId)
            ORDER BY c.Name, cb.Name", conn);
        cmd.Parameters.AddWithValue("@CampId",     (object?)campId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampbossId", (object?)campbossId ?? DBNull.Value);

        var list = new List<CampCampbossResponse>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new CampCampbossResponse
            {
                Id           = r.GetInt32(r.GetOrdinal("Id")),
                CampId       = r.GetInt32(r.GetOrdinal("CampId")),
                CampName     = r.GetString(r.GetOrdinal("CampName")),
                CampbossId   = r.GetInt32(r.GetOrdinal("CampbossId")),
                CampbossName = r.GetString(r.GetOrdinal("CampbossName")),
                CampbossCode = r.GetString(r.GetOrdinal("CampbossCode")),
                Type         = r.GetString(r.GetOrdinal("Type")),
                Amount       = r.GetDecimal(r.GetOrdinal("Amount")),
            });
        }
        return Ok(ApiResponse<IEnumerable<CampCampbossResponse>>.Ok(list, "Camp campbosses retrieved."));
    }

    /// <summary>
    /// POST /api/CampCampbosses/assign
    /// Ek campboss ko multiple camps assign karo (replace existing for that campboss)
    /// </summary>
    [HttpPost("assign")]
    public async Task<IActionResult> Assign([FromBody] AssignCampbossToCampRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        if (request.CampbossId <= 0) return BadRequest(ApiResponse<object>.Fail("CampbossId is required."));

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Soft-delete existing assignments for this campboss
        await using var delCmd = new SqlCommand(
            "UPDATE CampCampbosses SET IsDeleted=1, DeletedBy=@UserId, UpdatedAt=GETUTCDATE() WHERE CampbossId=@CampbossId AND ISNULL(IsDeleted,0)=0", conn);
        delCmd.Parameters.AddWithValue("@CampbossId", request.CampbossId);
        delCmd.Parameters.AddWithValue("@UserId", (object?)CurrentUserId ?? DBNull.Value);
        await delCmd.ExecuteNonQueryAsync();

        // Insert new assignments
        foreach (var item in request.Camps)
        {
            if (item.CampId <= 0) continue;
            await using var insCmd = new SqlCommand(
                "INSERT INTO CampCampbosses(CampId,CampbossId,Type,Amount,AddedBy,IsDeleted,CreatedAt,UpdatedAt) VALUES(@CampId,@CampbossId,@Type,@Amount,@AddedBy,0,GETUTCDATE(),GETUTCDATE())", conn);
            insCmd.Parameters.AddWithValue("@CampId",     item.CampId);
            insCmd.Parameters.AddWithValue("@CampbossId", request.CampbossId);
            insCmd.Parameters.AddWithValue("@Type",       item.Type ?? "");
            insCmd.Parameters.AddWithValue("@Amount",     item.Amount);
            insCmd.Parameters.AddWithValue("@AddedBy",    (object?)CurrentUserId ?? DBNull.Value);
            await insCmd.ExecuteNonQueryAsync();
        }

        await Log(ActivityType.Update, "CampCampboss",
            $"Assigned Campboss #{request.CampbossId} to {request.Camps.Count} camps",
            request.CampbossId.ToString(), "Campboss");

        return Ok(ApiResponse<object>.Ok(new { campbossId = request.CampbossId, assigned = request.Camps.Count },
            "Camps assigned to campboss successfully."));
    }

    /// <summary>
    /// DELETE /api/CampCampbosses/{id}
    /// Remove a single camp-campboss assignment (soft delete)
    /// </summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Remove(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(
            "UPDATE CampCampbosses SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id AND ISNULL(IsDeleted,0)=0", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)CurrentUserId ?? DBNull.Value);
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0
            ? Ok(ApiResponse<bool>.Ok(true, "Campboss removed from camp."))
            : NotFound(ApiResponse<bool>.Fail("Assignment not found."));
    }
}
