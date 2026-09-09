using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BufferFundTransferController : BaseApiController
{
    private readonly IBufferFundTransferService _service;

    public BufferFundTransferController(IBufferFundTransferService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    // GET /api/BufferFundTransfer
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] BufferFundTransferListRequest request)
        => Ok(await _service.GetAllAsync(request));

    // GET /api/BufferFundTransfer/{id}
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // POST /api/BufferFundTransfer
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateBufferFundTransferRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.CreateAsync(request, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Insert, ActivityModule.SalonMaster,
                $"BufferFundTransfer created | From:{request.FromFundPoolId} To:{request.ToFundPoolId} Amount:{request.Amount}",
                result.Data?.BufferFundTransferId.ToString() ?? "", "BufferFundTransfer");
        return result.Success ? Ok(result) : BadRequest(result);
    }

    // PUT /api/BufferFundTransfer/{id}
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateBufferFundTransferRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var result = await _service.UpdateAsync(id, request, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Update, ActivityModule.SalonMaster,
                $"BufferFundTransfer updated #{id}", id.ToString(), "BufferFundTransfer");
        return result.Success ? Ok(result) : NotFound(result);
    }

    // DELETE /api/BufferFundTransfer/{id}
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserName);
        if (result.Success)
            await Log(ActivityType.Delete, ActivityModule.SalonMaster,
                $"BufferFundTransfer deleted #{id}", id.ToString(), "BufferFundTransfer");
        return result.Success ? Ok(result) : NotFound(result);
    }
}
