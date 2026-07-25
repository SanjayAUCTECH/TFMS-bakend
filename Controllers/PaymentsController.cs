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
public class PaymentsController : BaseApiController
{
    private readonly IPaymentService    _service;
    private readonly IPaymentRepository _repo;
    public PaymentsController(IPaymentService service, IPaymentRepository repo, IActivityLogService log)
    { _service = service; _repo = repo; _activityLog = log; }

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

    [HttpGet("contract/{contractId}")]
    public async Task<IActionResult> GetByContractId(string contractId)
        => Ok(await _service.GetByContractIdAsync(contractId));

    [HttpGet("summary/{contractId}")]
    public async Task<IActionResult> GetSummary(string contractId)
    {
        var data = await _repo.GetSummaryAsync(contractId);
        return data == null
            ? NotFound(ApiResponse<PaymentSummaryResponse>.Fail("Contract not found."))
            : Ok(ApiResponse<PaymentSummaryResponse>.Ok(data, "Payment summary retrieved."));
    }

    [HttpGet("history/{contractId}")]
    public async Task<IActionResult> GetHistory(string contractId)
    {
        var data = await _repo.GetHistoryAsync(contractId);
        return Ok(ApiResponse<IEnumerable<PaymentHistoryResponse>>.Ok(data, "Payment history retrieved."));
    }

    [HttpPost("record")]
    public async Task<IActionResult> RecordPayment([FromBody] RecordPaymentRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.RecordPaymentAsync(request);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.Payments,
                $"Payment recorded for Contract {request.ContractId} Amount:{request.PaidAmount}",
                request.ContractId, "Payment");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    [HttpGet("rooms/{contractId}")]
    public async Task<IActionResult> GetContractRooms(string contractId)
    {
        var data = await _repo.GetContractRoomsForPaymentAsync(contractId);
        return Ok(ApiResponse<IEnumerable<ContractRoomPaymentInfo>>.Ok(data, "Contract rooms retrieved."));
    }

    [HttpGet("room-transactions/{contractId}")]
    public async Task<IActionResult> GetRoomTransactions(string contractId, [FromQuery] string? txnDate, [FromQuery] int? txnRecordId)
    {
        var data = await _repo.GetRoomTransactionsAsync(contractId, txnDate, txnRecordId);
        return Ok(ApiResponse<IEnumerable<RoomTransactionResponse>>.Ok(data, "Room transactions retrieved."));
    }
}
