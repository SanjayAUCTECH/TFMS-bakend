using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OtherPersonsController : BaseApiController
{
    private readonly IOtherPersonService _service;
    public OtherPersonsController(IOtherPersonService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    /// <summary>GET api/otherpersons?PageNumber=1&PageSize=10&Designation=Manager&Status=Active</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] OtherPersonListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateOtherPersonRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.OtherPersons, $"Created OtherPerson #{r.Data!.Id}", r.Data!.Id.ToString(), "OtherPerson");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateOtherPersonRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.OtherPersons, $"Updated OtherPerson #{id}", id.ToString(), "OtherPerson");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.OtherPersons, $"Deleted OtherPerson #{id}", id.ToString(), "OtherPerson");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
