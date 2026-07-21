using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

/// <summary>
/// Base controller — provides helper properties and activity logging shortcuts.
/// All API controllers can inherit from this instead of ControllerBase.
/// </summary>
public abstract class BaseApiController : ControllerBase
{
    protected IActivityLogService? _activityLog;

    protected int    CurrentUserId   => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
    protected string CurrentUserName => User.FindFirstValue(ClaimTypes.Name)  ?? "System";
    protected string CurrentUserRole => User.FindFirstValue(ClaimTypes.Role)  ?? "";
    protected string ClientIp        => HttpContext?.Connection?.RemoteIpAddress?.ToString() ?? "";
    protected string ClientAgent     => Request?.Headers["User-Agent"].ToString() ?? "";

    /// <summary>Log an activity — fire and forget, never throws</summary>
    protected Task Log(
        string activityType,
        string module,
        string action,
        string entityId   = "",
        string entityType = "",
        object? oldValues = null,
        object? newValues = null,
        string  status    = "Success",
        string? error     = null)
    {
        if (_activityLog == null) return Task.CompletedTask;
        return _activityLog.LogAsync(
            activityType, module, action,
            entityId, entityType, oldValues, newValues,
            CurrentUserId, CurrentUserName, CurrentUserRole,
            ClientIp, ClientAgent, status, error);
    }
}
