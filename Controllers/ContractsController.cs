using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContractsController : BaseApiController
{
    private readonly IContractService _service;
    public ContractsController(IContractService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] ContractListRequest request)
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

    [HttpGet("by-contractid/{contractId}")]
    public async Task<IActionResult> GetByContractId(string contractId)
    {
        var r = await _service.GetByContractIdAsync(contractId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpGet("{contractId}/document")]
    public async Task<IActionResult> GetDocument(string contractId)
    {
        var r = await _service.GetDocumentAsync(contractId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.Contracts, $"Created Contract #{r.Data!.ContractId}", r.Data!.ContractId, "Contract");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut]
    public async Task<IActionResult> UpdateContract([FromBody] UpdateContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateContractAsync(request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Contracts, $"Updated Contract {request.ContractId}", request.ContractId ?? "", "Contract");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    [HttpPatch("{contractId}/status")]
    public async Task<IActionResult> UpdateStatus(string contractId, [FromBody] UpdateContractStatusRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateStatusAsync(contractId, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Contracts, $"Status updated to '{request.Status}' for Contract {contractId}", contractId, "Contract");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    [HttpPatch("schedule")]
    public async Task<IActionResult> UpdateSchedule([FromBody] UpdateContractScheduleRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateScheduleAsync(request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Contracts, $"Payment schedule updated for Contract {request.ContractId}", request.ContractId ?? "", "Contract");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.Contracts, $"Deleted Contract #{id}", id.ToString(), "Contract");
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
