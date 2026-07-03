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
    private readonly IAuthService _service;
    public AuthController(IAuthService service) => _service = service;

    // ── Helper: get current user ID from JWT claims ───────────────────────────
    private int CurrentUserId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;

    // =========================================================================
    // PUBLIC (no token required)
    // =========================================================================

    /// <summary>
    /// POST api/auth/login
    /// Authenticate with username + password and receive JWT token.
    /// Default admin: admin / Admin@123
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.LoginAsync(request);
        return result.Success ? Ok(result) : Unauthorized(result);
    }

    // =========================================================================
    // PROTECTED (JWT token required)
    // =========================================================================

    /// <summary>
    /// GET api/auth/profile
    /// Get logged-in user's own profile.
    /// </summary>
    [HttpGet("profile")]
    [Authorize]
    public async Task<IActionResult> GetProfile()
    {
        var result = await _service.GetProfileAsync(CurrentUserId);
        return result.Success ? Ok(result) : NotFound(result);
    }

    /// <summary>
    /// PUT api/auth/profile
    /// Update logged-in user's name, contact, email.
    /// </summary>
    [HttpPut("profile")]
    [Authorize]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateProfileAsync(CurrentUserId, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// POST api/auth/change-password
    /// Change password — requires current password verification.
    /// Body: { currentPassword, newPassword, confirmPassword }
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.ChangePasswordAsync(CurrentUserId, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// POST api/auth/refresh-token
    /// Get a new JWT token using the current valid token (no body needed).
    /// Call this before token expires to stay logged in.
    /// </summary>
    [HttpPost("refresh-token")]
    [Authorize]
    public async Task<IActionResult> RefreshToken()
    {
        var result = await _service.RefreshTokenAsync(CurrentUserId);
        return result.Success ? Ok(result) : Unauthorized(result);
    }

    /// <summary>
    /// PATCH api/auth/menu-access
    /// Update logged-in user's menu access (JSON object).
    /// Body: { menuAccess: "{ dashboard: true, partners: true, ... }" }
    /// </summary>
    [HttpPatch("menu-access")]
    [Authorize]
    public async Task<IActionResult> UpdateMenuAccess([FromBody] UpdateMenuAccessRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateMenuAccessAsync(CurrentUserId, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// POST api/auth/logout
    /// Logout — client should discard the token (JWT is stateless).
    /// Server records the logout timestamp.
    /// </summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout()
    {
        var result = await _service.LogoutAsync(CurrentUserId);
        return Ok(result);
    }

    /// <summary>
    /// GET api/auth/me
    /// Quick check — returns current user info from JWT claims (no DB call).
    /// </summary>
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
