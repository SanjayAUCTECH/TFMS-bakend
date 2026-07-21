using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService        _service;
    private readonly IActivityLogService _log;

    public AuthController(IAuthService service, IActivityLogService log)
    {
        _service = service;
        _log     = log;
    }

    private int    CurrentUserId   => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
    private string CurrentUserName => User.FindFirstValue(ClaimTypes.Name) ?? "";
    private string CurrentUserRole => User.FindFirstValue(ClaimTypes.Role) ?? "";
    private string ClientIp        => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "";
    private string ClientAgent     => Request.Headers["User-Agent"].ToString();

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.LoginAsync(request);

        // Log login attempt
        await _log.LogAsync(
            activityType: ActivityType.Login,
            module:       ActivityModule.Auth,
            action:       result.Success
                ? $"User '{request.Username}' logged in successfully"
                : $"Failed login attempt for '{request.Username}'",
            entityId:     request.Username,
            entityType:   "User",
            userName:     request.Username,
            ipAddress:    ClientIp,
            userAgent:    ClientAgent,
            status:       result.Success ? "Success" : "Failed",
            errorMessage: result.Success ? null : result.Message
        );

        return result.Success ? Ok(result) : Unauthorized(result);
    }

    [HttpGet("profile")]
    [Authorize]
    public async Task<IActionResult> GetProfile()
    {
        var result = await _service.GetProfileAsync(CurrentUserId);
        return result.Success ? Ok(result) : NotFound(result);
    }

    [HttpPut("profile")]
    [Authorize]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateProfileAsync(CurrentUserId, request);

        if (result.Success)
            await _log.LogAsync(ActivityType.Update, ActivityModule.Auth,
                $"User '{CurrentUserName}' updated profile",
                CurrentUserId.ToString(), "User",
                userId: CurrentUserId, userName: CurrentUserName, userRole: CurrentUserRole,
                ipAddress: ClientIp, userAgent: ClientAgent);

        return result.Success ? Ok(result) : BadRequest(result);
    }

    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.ChangePasswordAsync(CurrentUserId, request);

        await _log.LogAsync(ActivityType.Update, ActivityModule.Auth,
            $"User '{CurrentUserName}' changed password",
            CurrentUserId.ToString(), "User",
            userId: CurrentUserId, userName: CurrentUserName, userRole: CurrentUserRole,
            ipAddress: ClientIp, userAgent: ClientAgent,
            status: result.Success ? "Success" : "Failed");

        return result.Success ? Ok(result) : BadRequest(result);
    }

    [HttpPost("refresh-token")]
    [Authorize]
    public async Task<IActionResult> RefreshToken()
    {
        var result = await _service.RefreshTokenAsync(CurrentUserId);
        return result.Success ? Ok(result) : Unauthorized(result);
    }

    [HttpPatch("menu-access")]
    [Authorize]
    public async Task<IActionResult> UpdateMenuAccess([FromBody] UpdateMenuAccessRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateMenuAccessAsync(CurrentUserId, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout()
    {
        await _log.LogAsync(ActivityType.Logout, ActivityModule.Auth,
            $"User '{CurrentUserName}' logged out",
            CurrentUserId.ToString(), "User",
            userId: CurrentUserId, userName: CurrentUserName, userRole: CurrentUserRole,
            ipAddress: ClientIp, userAgent: ClientAgent);

        var result = await _service.LogoutAsync(CurrentUserId);
        return Ok(result);
    }

    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        return Ok(new
        {
            success = true,
            data = new
            {
                userId   = CurrentUserId,
                username = User.FindFirstValue(ClaimTypes.Name),
                role     = User.FindFirstValue(ClaimTypes.Role),
                isAdmin  = User.FindFirstValue("IsAdmin"),
                userCode = User.FindFirstValue("UserId"),
            }
        });
    }
}
