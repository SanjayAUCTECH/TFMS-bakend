using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AccountMastersController : BaseApiController
{
    private readonly IAccountMasterService _service;

    public AccountMastersController(IAccountMasterService service, IActivityLogService log)
    {
        _service = service;
        _activityLog = log;
    }

    /// <summary>GET api/accountmasters?PageNumber=1&PageSize=10&PaymentType=Income&DateFrom=2026-01-01</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] AccountMasterListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    /// <summary>GET api/accountmasters/{id}</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>POST api/accountmasters</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateAccountMasterRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.AccountsHeads,
                $"Created AccountMaster #{r.Data!.Id} ({r.Data.AccountId})",
                r.Data.Id.ToString(), "AccountMaster");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    /// <summary>PUT api/accountmasters/{id}</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateAccountMasterRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.AccountsHeads,
                $"Updated AccountMaster #{id}",
                id.ToString(), "AccountMaster");
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>DELETE api/accountmasters/{id}</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.AccountsHeads,
                $"Deleted AccountMaster #{id}",
                id.ToString(), "AccountMaster");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
