using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonStaffAssignController : BaseApiController
{
    private readonly ISalonStaffAssignService _service;

    public SalonStaffAssignController(ISalonStaffAssignService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    // ── GET /api/SalonStaffAssign
    // Filters: PageNumber, PageSize, SearchText, SalonId, Status
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] SalonStaffAssignListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    // ── GET /api/SalonStaffAssign/{assignId}
    [HttpGet("{assignId:int}")]
    public async Task<IActionResult> GetById(int assignId)
    {
        var result = await _service.GetByIdAsync(assignId);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── POST /api/SalonStaffAssign
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSalonStaffAssignRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.CreateAsync(request, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Insert,
                ActivityModule.SalonMaster,
                $"Assigned Staff #{request.StaffId} to Salon #{request.SalonId} (AssignId #{result.Data!.AssignId})",
                result.Data.AssignId.ToString(),
                "SalonStaffAssign");

        return result.Success
            ? CreatedAtAction(nameof(GetById), new { assignId = result.Data!.AssignId }, result)
            : BadRequest(result);
    }

    // ── PUT /api/SalonStaffAssign/{assignId}
    [HttpPut("{assignId:int}")]
    public async Task<IActionResult> Update(int assignId, [FromBody] UpdateSalonStaffAssignRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.UpdateAsync(assignId, request, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Update,
                ActivityModule.SalonMaster,
                $"Updated SalonStaffAssign #{assignId}",
                assignId.ToString(),
                "SalonStaffAssign");

        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── DELETE /api/SalonStaffAssign/{assignId}
    [HttpDelete("{assignId:int}")]
    public async Task<IActionResult> Delete(int assignId)
    {
        var result = await _service.DeleteAsync(assignId, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Delete,
                ActivityModule.SalonMaster,
                $"Deleted SalonStaffAssign #{assignId}",
                assignId.ToString(),
                "SalonStaffAssign");

        return result.Success ? Ok(result) : NotFound(result);
    }
}
