using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RoomStatusesController : BaseApiController
{
    private readonly IRoomStatusService _service;
    public RoomStatusesController(IRoomStatusService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _service.GetAllAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRoomStatusRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateRoomStatusRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        return r.Success ? Ok(r) : NotFound(r);
    }
}
