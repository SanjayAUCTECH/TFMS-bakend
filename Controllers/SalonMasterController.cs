using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonMasterController : BaseApiController
{
    private readonly ISalonMasterService _service;

    public SalonMasterController(ISalonMasterService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    // ── GET /api/SalonMaster ──────────────────────────────────────────────────
    /// <summary>Get all salons (paginated, filterable by Status/SearchText)</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] SalonMasterListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    // ── GET /api/SalonMaster/{id} ─────────────────────────────────────────────
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── POST /api/SalonMaster ─────────────────────────────────────────────────
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSalonMasterRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.CreateAsync(request, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Insert,
                ActivityModule.SalonMaster,
                $"Created Salon Master: {result.Data!.Name} (#{result.Data.Id})",
                result.Data.Id.ToString(),
                "SalonMaster");

        return result.Success
            ? CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result)
            : BadRequest(result);
    }

    // ── PUT /api/SalonMaster/{id} ─────────────────────────────────────────────
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateSalonMasterRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.UpdateAsync(id, request, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Update,
                ActivityModule.SalonMaster,
                $"Updated Salon Master: {result.Data!.Name} (#{id})",
                id.ToString(),
                "SalonMaster");

        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── DELETE /api/SalonMaster/{id} ──────────────────────────────────────────
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserId);

        if (result.Success)
            await Log(
                ActivityType.Delete,
                ActivityModule.SalonMaster,
                $"Deleted Salon Master #{id}",
                id.ToString(),
                "SalonMaster");

        return result.Success ? Ok(result) : NotFound(result);
    }
}
