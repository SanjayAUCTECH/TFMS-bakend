using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContractsController : ControllerBase
{
    private readonly IContractService _service;
    public ContractsController(IContractService service) => _service = service;

    /// <summary>GET api/contracts?PageNumber=1&PageSize=10&Status=Active&TenantId=1&CampId=2</summary>
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

    /// <summary>GET api/contracts/by-contractid/CNT-000001</summary>
    [HttpGet("by-contractid/{contractId}")]
    public async Task<IActionResult> GetByContractId(string contractId)
    {
        var r = await _service.GetByContractIdAsync(contractId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>
    /// GET api/contracts/{contractId}/document
    /// Full contract document data — for 2-page and 3-page contract preview/print.
    /// Returns contract + tenant + lessor + property + rooms + installments + payment summary.
    /// </summary>
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
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    /// <summary>PUT api/contracts — Update contract details + rooms</summary>
    [HttpPut]
    public async Task<IActionResult> UpdateContract([FromBody] UpdateContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateContractAsync(request);
        return r.Success ? Ok(r) : BadRequest(r);
    }
    [HttpPatch("{contractId}/status")]
    public async Task<IActionResult> UpdateStatus(string contractId, [FromBody] UpdateContractStatusRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateStatusAsync(contractId, request);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>PATCH api/contracts/schedule — Save payment schedule (mode/date/amount per installment)</summary>
    [HttpPatch("schedule")]
    public async Task<IActionResult> UpdateSchedule([FromBody] UpdateContractScheduleRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateScheduleAsync(request);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id);
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
