using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RoomsController : ControllerBase
{
    private readonly IRoomService    _service;
    private readonly IRoomRepository _repo;
    public RoomsController(IRoomService service, IRoomRepository repo)
    { _service = service; _repo = repo; }

    /// <summary>GET api/rooms?CampId=1&FloorId=2&RoomStatus=Vacant&PageNumber=1&PageSize=10</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] RoomListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    /// <summary>GET api/rooms/vacant/1 — Vacant rooms for a specific camp (for contract creation).</summary>
    [HttpGet("vacant/{campId:int}")]
    public async Task<IActionResult> GetVacantByCamp(int campId) => Ok(await _service.GetVacantByCampAsync(campId));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRoomRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    /// <summary>POST api/rooms/bulk — Create multiple rooms in one call</summary>
    [HttpPost("bulk")]
    public async Task<IActionResult> BulkCreate([FromBody] BulkCreateRoomRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        if (request.RoomNos == null || request.RoomNos.Count == 0)
            return BadRequest(Common.ApiResponse<BulkCreateRoomResponse>.Fail("RoomNos list is required."));
        if (request.RoomNos.Count > 2000)
            return BadRequest(Common.ApiResponse<BulkCreateRoomResponse>.Fail("Maximum 2000 rooms at a time."));
        var result = await _repo.BulkCreateAsync(request);
        return Ok(Common.ApiResponse<BulkCreateRoomResponse>.Ok(result,
            $"Bulk create done: {result.Created} created, {result.Skipped} skipped."));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateRoomRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }
}
