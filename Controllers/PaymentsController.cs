using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _service;
    public PaymentsController(IPaymentService service) => _service = service;

    /// <summary>
    /// GET api/payments — Monthly Due list with full filters.
    /// Supports: ContractId, TenantId, CampId, Month, Year, PaymentStatus, PaymentModeId, DateFrom, DateTo
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] PaymentListRequest request)
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

    /// <summary>GET api/payments/contract/CNT-000001 — All installments of a contract.</summary>
    [HttpGet("contract/{contractId}")]
    public async Task<IActionResult> GetByContractId(string contractId)
        => Ok(await _service.GetByContractIdAsync(contractId));

    /// <summary>POST api/payments/record — Record a payment for an installment.</summary>
    [HttpPost("record")]
    public async Task<IActionResult> RecordPayment([FromBody] RecordPaymentRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.RecordPaymentAsync(request);
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
