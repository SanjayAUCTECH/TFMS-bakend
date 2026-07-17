using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContractCancellationsController : ControllerBase
{
    private readonly IContractCancellationRepository _repo;
    private readonly IContractRepository _contractRepo;

    public ContractCancellationsController(IContractCancellationRepository repo, IContractRepository contractRepo)
    {
        _repo = repo;
        _contractRepo = contractRepo;
    }

    /// <summary>
    /// POST api/contractcancellations/cancel
    /// Cancel a contract — marks status as Cancelled, cancels pending installments,
    /// logs cancellation, creates penalty DR / refund CR transactions.
    /// </summary>
    [HttpPost("cancel")]
    public async Task<IActionResult> Cancel([FromBody] CancelContractRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ContractId))
            return BadRequest(ApiResponse<object>.Fail("ContractId is required."));

        var contract = await _contractRepo.GetByContractIdAsync(request.ContractId);
        if (contract == null)
            return NotFound(ApiResponse<object>.Fail($"Contract '{request.ContractId}' not found."));

        if (contract.Status == "Cancelled")
            return BadRequest(ApiResponse<object>.Fail("Contract is already cancelled."));

        try
        {
            var newId = await _repo.CancelAsync(request);
            return Ok(ApiResponse<object>.Ok(new
            {
                id = newId,
                contractId = request.ContractId,
                status = "Cancelled",
                refundAmount = request.RefundAmount,
                penaltyAmount = request.PenaltyAmount,
                settlementAmount = request.SettlementAmount,
            }, $"Contract {request.ContractId} cancelled successfully."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Cancellation failed: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/contractcancellations?contractId=CNT-000020
    /// Get cancellation history (optional contractId filter).
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? contractId)
    {
        var data = await _repo.GetAllAsync(contractId);
        return Ok(ApiResponse<IEnumerable<ContractCancellationResponse>>.Ok(data, "Cancellations retrieved."));
    }
}
