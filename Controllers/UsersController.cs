using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _service;
    public UsersController(IUserService service) => _service = service;

    /// <summary>GET api/users?PageNumber=1&PageSize=10&Role=Admin&Status=Active</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] UserListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    /// <summary>GET api/users/5</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>POST api/users</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    /// <summary>PUT api/users/5</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUserRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>POST api/users/5/change-password</summary>
    [HttpPost("{id:int}/change-password")]
    public async Task<IActionResult> ChangePassword(int id, [FromBody] ChangePasswordRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.ChangePasswordAsync(id, request);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>POST api/users/5/reset-password — Admin only</summary>
    [HttpPost("{id:int}/reset-password")]
    public async Task<IActionResult> ResetPassword(int id, [FromBody] ResetPasswordRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.ResetPasswordAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>PATCH api/users/5/login-access — Enable or disable login</summary>
    [HttpPatch("{id:int}/login-access")]
    public async Task<IActionResult> UpdateLoginAccess(int id, [FromBody] UpdateLoginAccessRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateLoginAccessAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>PATCH api/users/5/menu-access</summary>
    [HttpPatch("{id:int}/menu-access")]
    public async Task<IActionResult> UpdateMenuAccess(int id, [FromBody] UpdateMenuAccessRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateMenuAccessAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>DELETE api/users/5</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }
}
