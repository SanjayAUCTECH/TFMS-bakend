using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AccountsHeadsController : ControllerBase
{
    private readonly IAccountsHeadService _service;
    public AccountsHeadsController(IAccountsHeadService service) => _service = service;

    /// <summary>GET api/accountsheads?PageNumber=1&PageSize=10&Type=Asset&Status=Active</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] AccountsHeadListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetAllActive() => Ok(await _service.GetAllActiveAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) { var r = await _service.GetByIdAsync(id); return r.Success ? Ok(r) : NotFound(r); }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateAccountsHeadRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateAccountsHeadRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id) { var r = await _service.DeleteAsync(id); return r.Success ? Ok(r) : NotFound(r); }
}
