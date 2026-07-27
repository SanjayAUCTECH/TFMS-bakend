using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : BaseApiController
{
    private readonly IUserService _service;
    public UsersController(IUserService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] UserListRequest request)
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
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.Users, $"Created User '{request.Username}' #{r.Data!.Id}", r.Data!.Id.ToString(), "User");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUserRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Users, $"Updated User #{id}", id.ToString(), "User");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost("{id:int}/change-password")]
    public async Task<IActionResult> ChangePassword(int id, [FromBody] ChangePasswordRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.ChangePasswordAsync(id, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Users, $"Password changed for User #{id}", id.ToString(), "User");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    [HttpPost("{id:int}/reset-password")]
    public async Task<IActionResult> ResetPassword(int id, [FromBody] ResetPasswordRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.ResetPasswordAsync(id, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Users, $"Password reset for User #{id}", id.ToString(), "User");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPatch("{id:int}/login-access")]
    public async Task<IActionResult> UpdateLoginAccess(int id, [FromBody] UpdateLoginAccessRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateLoginAccessAsync(id, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Users, $"Login access updated to '{request.LoginAccess}' for User #{id}", id.ToString(), "User");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPatch("{id:int}/menu-access")]
    public async Task<IActionResult> UpdateMenuAccess(int id, [FromBody] UpdateMenuAccessRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateMenuAccessAsync(id, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Users, $"Menu access updated for User #{id}", id.ToString(), "User");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.Users, $"Deleted User #{id}", id.ToString(), "User");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
