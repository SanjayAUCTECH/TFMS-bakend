using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TaskAlertController : BaseApiController
{
    private readonly ITaskAlertService _service;
    public TaskAlertController(ITaskAlertService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    /// <summary>
    /// GET api/taskalert?PageNumber=1&PageSize=10&TaskStatus=Running&AssignPersonId=5&DateFrom=2026-01-01
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] TaskAlertListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    /// <summary>GET api/taskalert/{id}</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>
    /// GET api/taskalert/alerts?assignPersonId=5
    /// Returns ACTIVE alerts: TaskDate &lt;= TODAY &amp;&amp; Status = Running or Partial
    /// </summary>
    [HttpGet("alerts")]
    public async Task<IActionResult> GetActiveAlerts([FromQuery] int? assignPersonId = null)
    {
        return Ok(await _service.GetActiveAlertsAsync(assignPersonId));
    }

    /// <summary>POST api/taskalert</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateTaskAlertRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.TaskAlerts,
                $"Created TaskAlert #{r.Data!.Id} '{r.Data.TaskTitle}'",
                r.Data.Id.ToString(), "TaskAlert");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    /// <summary>PUT api/taskalert/{id}</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateTaskAlertRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.TaskAlerts,
                $"Updated TaskAlert #{id}", id.ToString(), "TaskAlert");
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>DELETE api/taskalert/{id}</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.TaskAlerts,
                $"Deleted TaskAlert #{id}", id.ToString(), "TaskAlert");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
