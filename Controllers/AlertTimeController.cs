using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AlertTimeController : ControllerBase
{
    private readonly IAlertTimeService   _service;
    private readonly IActivityLogService _log;

    public AlertTimeController(IAlertTimeService service, IActivityLogService log)
    {
        _service = service;
        _log     = log;
    }

    private int    CurrentUserId   => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
    private string CurrentUserName => User.FindFirstValue(ClaimTypes.Name) ?? "";
    private string CurrentUserRole => User.FindFirstValue(ClaimTypes.Role) ?? "";
    private string ClientIp        => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "";
    private string ClientAgent     => Request.Headers["User-Agent"].ToString();

    // ── GET: api/AlertTime ────────────────────────────────────────
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] AlertTimeListRequest request)
    {
        var result = await _service.GetAllAsync(request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── GET: api/AlertTime/{id} ───────────────────────────────────
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── POST: api/AlertTime ───────────────────────────────────────
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateAlertTimeRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.CreateAsync(request, CurrentUserId);

        if (result.Success)
            await _log.LogAsync(ActivityType.Create, ActivityModule.Settings,
                $"Created alert time: {request.AlertName}",
                result.Data?.Id.ToString() ?? "", "AlertTime",
                userId: CurrentUserId, userName: CurrentUserName, userRole: CurrentUserRole,
                ipAddress: ClientIp, userAgent: ClientAgent);

        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── PUT: api/AlertTime/{id} ───────────────────────────────────
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateAlertTimeRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.UpdateAsync(id, request, CurrentUserId);

        if (result.Success)
            await _log.LogAsync(ActivityType.Update, ActivityModule.Settings,
                $"Updated alert time: {request.AlertName}",
                id.ToString(), "AlertTime",
                userId: CurrentUserId, userName: CurrentUserName, userRole: CurrentUserRole,
                ipAddress: ClientIp, userAgent: ClientAgent);

        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── DELETE: api/AlertTime/{id} ────────────────────────────────
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserId);

        if (result.Success)
            await _log.LogAsync(ActivityType.Delete, ActivityModule.Settings,
                $"Deleted alert time ID: {id}",
                id.ToString(), "AlertTime",
                userId: CurrentUserId, userName: CurrentUserName, userRole: CurrentUserRole,
                ipAddress: ClientIp, userAgent: ClientAgent);

        return result.Success ? Ok(result) : NotFound(result);
    }
}
