using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OwnersController : BaseApiController
{
    private readonly IOwnerService _service;
    public OwnersController(IOwnerService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] OwnerListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateOwnerRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.CreateAsync(request, CurrentUserId);
        if (result.Success)
            await Log(ActivityType.Insert, "Owners", $"Created Owner #{result.Data!.Id}", result.Data!.Id.ToString(), "Owner");
        return result.Success ? CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result) : BadRequest(result);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateOwnerRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateAsync(id, request, CurrentUserId);
        if (result.Success)
            await Log(ActivityType.Update, "Owners", $"Updated Owner #{id}", id.ToString(), "Owner");
        return result.Success ? Ok(result) : NotFound(result);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserId);
        if (result.Success)
            await Log(ActivityType.Delete, "Owners", $"Deleted Owner #{id}", id.ToString(), "Owner");
        return result.Success ? Ok(result) : NotFound(result);
    }
}
