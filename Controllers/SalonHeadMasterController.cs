using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonHeadMasterController : BaseApiController
{
    private readonly ISalonHeadMasterService _service;

    public SalonHeadMasterController(ISalonHeadMasterService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    // ── GET /api/SalonHeadMaster
    // Query params: PageNumber, PageSize, SearchText, HeadType, Status
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] SalonHeadMasterListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    // ── GET /api/SalonHeadMaster/active?headType=Income
    [HttpGet("active")]
    public async Task<IActionResult> GetAllActive([FromQuery] string? headType = null)
        => Ok(await _service.GetAllActiveAsync(headType));

    // ── GET /api/SalonHeadMaster/{id}
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── POST /api/SalonHeadMaster
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSalonHeadMasterRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.CreateAsync(request, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Insert,
                ActivityModule.SalonMaster,
                $"Created Salon Head: [{result.Data!.HeadType}] {result.Data.HeadName} (#{result.Data.Id})",
                result.Data.Id.ToString(),
                "SalonHeadMaster");

        return result.Success
            ? CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result)
            : BadRequest(result);
    }

    // ── PUT /api/SalonHeadMaster/{id}
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateSalonHeadMasterRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.UpdateAsync(id, request, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Update,
                ActivityModule.SalonMaster,
                $"Updated Salon Head: [{result.Data!.HeadType}] {result.Data.HeadName} (#{id})",
                id.ToString(),
                "SalonHeadMaster");

        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── DELETE /api/SalonHeadMaster/{id}
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Delete,
                ActivityModule.SalonMaster,
                $"Deleted Salon Head #{id}",
                id.ToString(),
                "SalonHeadMaster");

        return result.Success ? Ok(result) : NotFound(result);
    }
}
