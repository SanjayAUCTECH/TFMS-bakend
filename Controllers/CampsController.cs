using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CampsController : BaseApiController
{
    private readonly ICampService _service;
    public CampsController(ICampService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] CampListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetAllActive() => Ok(await _service.GetAllActiveAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCampRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.Camps, $"Created Camp '{request.Name}' #{r.Data!.Id}", r.Data!.Id.ToString(), "Camp");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCampRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Camps, $"Updated Camp #{id}", id.ToString(), "Camp");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.Camps, $"Deleted Camp #{id}", id.ToString(), "Camp");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
