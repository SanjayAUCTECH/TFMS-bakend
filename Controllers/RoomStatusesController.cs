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
    public async Task<IActionResult> GetAll([FromQuery] string? searchText)
    {
        var result = await _service.GetAllAsync();
        if (!result.Success) return Ok(result);

        // C# mein search filter lagao
        if (!string.IsNullOrWhiteSpace(searchText))
        {
            var search = searchText.Trim().ToLower();
            var filtered = result.Data!.Where(r => r.Name.ToLower().Contains(search));
            return Ok(Common.ApiResponse<IEnumerable<RoomStatusResponse>>.Ok(filtered, result.Message));
        }
        return Ok(result);
    }

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
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.Rooms, $"Created RoomStatus #{r.Data!.Id} '{r.Data.Name}'", r.Data!.Id.ToString(), "RoomStatus");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateRoomStatusRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Rooms, $"Updated RoomStatus #{id}", id.ToString(), "RoomStatus");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.Rooms, $"Deleted RoomStatus #{id}", id.ToString(), "RoomStatus");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
