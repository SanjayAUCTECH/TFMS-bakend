using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CurrentFundTransferController : BaseApiController
{
    private readonly ICurrentFundTransferService _service;

    public CurrentFundTransferController(ICurrentFundTransferService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    // GET /api/CurrentFundTransfer
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] CurrentFundTransferListRequest request)
        => Ok(await _service.GetAllAsync(request));

    // GET /api/CurrentFundTransfer/{id}
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // POST /api/CurrentFundTransfer
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCurrentFundTransferRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.CreateAsync(request, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Insert, ActivityModule.SalonMaster,
                $"CurrentFundTransfer created | From:{request.FromFundPoolId} To:{request.ToFundPoolId} Amount:{request.Amount}",
                result.Data?.CurrentFundTransferId.ToString() ?? "", "CurrentFundTransfer");
        return result.Success ? Ok(result) : BadRequest(result);
    }

    // PUT /api/CurrentFundTransfer/{id}
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCurrentFundTransferRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateAsync(id, request, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Update, ActivityModule.SalonMaster,
                $"CurrentFundTransfer updated #{id}", id.ToString(), "CurrentFundTransfer");
        return result.Success ? Ok(result) : NotFound(result);
    }

    // DELETE /api/CurrentFundTransfer/{id}
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Delete, ActivityModule.SalonMaster,
                $"CurrentFundTransfer deleted #{id}", id.ToString(), "CurrentFundTransfer");
        return result.Success ? Ok(result) : NotFound(result);
    }
}
