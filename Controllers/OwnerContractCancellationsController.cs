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
public class OwnerContractCancellationsController : BaseApiController
{
    private readonly IOwnerContractCancellationRepository _repo;
    private readonly IOwnerContractRepository             _contractRepo;

    public OwnerContractCancellationsController(
        IOwnerContractCancellationRepository repo,
        IOwnerContractRepository contractRepo,
        IActivityLogService log)
    {
        _repo         = repo;
        _contractRepo = contractRepo;
        _activityLog  = log;
    }

    /// <summary>
    /// POST api/ownercontractcancellations/cancel
    /// Owner contract cancel karo — status Cancelled ho jayega,
    /// installments Cancelled ho jayengi, cancellation record save hoga.
    /// </summary>
    [HttpPost("cancel")]
    public async Task<IActionResult> Cancel([FromBody] CancelOwnerContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        // Contract exist check
        var contract = await _contractRepo.GetByIdAsync(request.OwnerContractId);
        if (contract == null)
            return NotFound(ApiResponse<object>.Fail($"Owner contract #{request.OwnerContractId} not found."));

        // Already cancelled check
        if (contract.Status == "Cancelled")
            return BadRequest(ApiResponse<object>.Fail("Owner contract is already cancelled."));

        try
        {
            var newId = await _repo.CancelAsync(request, CurrentUserId);

            await Log(ActivityType.Update, ActivityModule.OwnerContracts,
                $"Owner Contract #{request.OwnerContractId} ({contract.OcCode}) cancelled",
                request.OwnerContractId.ToString(), "OwnerContract");

            return Ok(ApiResponse<object>.Ok(new
            {
                id              = newId,
                ownerContractId = request.OwnerContractId,
                ocCode          = contract.OcCode,
                status          = "Cancelled",
                cancellationDate= request.CancellationDate,
                remarks         = request.Remarks,
                cancelledBy     = request.CancelledBy,
            }, $"Owner contract {contract.OcCode} cancelled successfully."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Cancellation failed: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/ownercontractcancellations?ownerContractId=5
    /// Cancellation history — optional ownerContractId filter
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int? ownerContractId)
    {
        var data = await _repo.GetAllAsync(ownerContractId);
        return Ok(ApiResponse<IEnumerable<OwnerContractCancellationResponse>>.Ok(data, "Cancellations retrieved."));
    }
}
