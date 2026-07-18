using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContractRenewalsController : ControllerBase
{
    private readonly IContractRenewalRepository _repo;
    private readonly IContractRepository _contractRepo;

    public ContractRenewalsController(IContractRenewalRepository repo, IContractRepository contractRepo)
    {
        _repo = repo;
        _contractRepo = contractRepo;
    }

    /// <summary>
    /// POST api/contractrenewals/renew
    /// Renew an existing contract — creates new contract + installments + DR TxnRecord
    /// Optionally expires the old contract.
    /// </summary>
    [HttpPost("renew")]
    public async Task<IActionResult> Renew([FromBody] RenewContractRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.OriginalContractId))
            return BadRequest(ApiResponse<object>.Fail("OriginalContractId is required."));

        // Verify original contract exists
        var original = await _contractRepo.GetByContractIdAsync(request.OriginalContractId);
        if (original == null)
            return NotFound(ApiResponse<object>.Fail($"Contract '{request.OriginalContractId}' not found."));

        // Default tenant/camps/rooms from original if not provided
        if (!request.TenantId.HasValue || request.TenantId == 0)
            request.TenantId = original.TenantId;
        if (request.CampIds == null || request.CampIds.Count == 0)
            request.CampIds = original.CampIds;

        // Derive RoomIds from Rooms array or fallback to original
        List<int>? roomIds = null;
        if (request.Rooms != null && request.Rooms.Count > 0)
            roomIds = request.Rooms.Select(r => r.RoomId).ToList();
        else
            roomIds = original.RoomIds;

        // Default property fields from original
        if (string.IsNullOrEmpty(request.ContractPropertyUsage))
            request.ContractPropertyUsage = original.ContractPropertyUsage;
        if (string.IsNullOrEmpty(request.ContractBuildingName))
            request.ContractBuildingName = original.ContractBuildingName;
        if (string.IsNullOrEmpty(request.ContractPropertyType))
            request.ContractPropertyType = original.ContractPropertyType;
        if (string.IsNullOrEmpty(request.ContractLocation))
            request.ContractLocation = original.ContractLocation;
        if (string.IsNullOrEmpty(request.ContractPropertyNo))
            request.ContractPropertyNo = original.ContractPropertyNo;
        if (string.IsNullOrEmpty(request.ContractPropertyArea))
            request.ContractPropertyArea = original.ContractPropertyArea;
        if (string.IsNullOrEmpty(request.ContractPremisesNo))
            request.ContractPremisesNo = original.ContractPremisesNo;
        if (string.IsNullOrEmpty(request.ContractPaymentMode))
            request.ContractPaymentMode = original.ContractPaymentMode;
        if (string.IsNullOrEmpty(request.ContractPlotNo))
            request.ContractPlotNo = original.ContractPlotNo;
        if (string.IsNullOrEmpty(request.ContractMakaniNo))
            request.ContractMakaniNo = original.ContractMakaniNo;

        try
        {
            var newContractId = await _repo.RenewAsync(request);

            // Fetch the newly created contract
            var newContract = await _contractRepo.GetByContractIdAsync(newContractId);

            return Ok(ApiResponse<object>.Ok(new
            {
                originalContractId = request.OriginalContractId,
                newContractId,
                renewalType = request.RenewalType,
                tenantId = request.TenantId,
                startDate = request.StartDate?.ToString("yyyy-MM-dd"),
                months = request.Months,
                monthlyTotal = request.MonthlyTotal,
                contractTotal = request.ContractTotal,
                installmentType = request.InstallmentType,
                status = "Active",
                message = $"Contract renewed successfully. Old: {request.OriginalContractId} → New: {newContractId}"
            }, $"Contract renewed successfully. New contract: {newContractId}"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Renewal failed: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/contractrenewals?contractId=CNT-000106
    /// Get renewal history for a contract (optional contractId filter).
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetRenewals([FromQuery] string? contractId)
    {
        var data = await _repo.GetRenewalsAsync(contractId);
        return Ok(ApiResponse<IEnumerable<ContractRenewalResponse>>.Ok(data, "Renewals retrieved."));
    }
}
