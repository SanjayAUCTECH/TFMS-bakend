using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService    _service;
    private readonly IPaymentRepository _repo;
    public PaymentsController(IPaymentService service, IPaymentRepository repo)
    { _service = service; _repo = repo; }

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

    /// <summary>GET api/payments/contract/{contractId} — All installments of a contract.</summary>
    [HttpGet("contract/{contractId}")]
    public async Task<IActionResult> GetByContractId(string contractId)
        => Ok(await _service.GetByContractIdAsync(contractId));

    /// <summary>GET api/payments/summary/{contractId} — Financial summary card for Make Payment page.</summary>
    [HttpGet("summary/{contractId}")]
    public async Task<IActionResult> GetSummary(string contractId)
    {
        var data = await _repo.GetSummaryAsync(contractId);
        return data == null
            ? NotFound(ApiResponse<PaymentSummaryResponse>.Fail("Contract not found."))
            : Ok(ApiResponse<PaymentSummaryResponse>.Ok(data, "Payment summary retrieved."));
    }

    /// <summary>GET api/payments/history/{contractId} — Full payment history for receipt & list.</summary>
    [HttpGet("history/{contractId}")]
    public async Task<IActionResult> GetHistory(string contractId)
    {
        var data = await _repo.GetHistoryAsync(contractId);
        return Ok(ApiResponse<IEnumerable<PaymentHistoryResponse>>.Ok(data, "Payment history retrieved."));
    }

    /// <summary>POST api/payments/record — Record a payment for an installment.</summary>
    [HttpPost("record")]
    public async Task<IActionResult> RecordPayment([FromBody] RecordPaymentRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.RecordPaymentAsync(request);
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
