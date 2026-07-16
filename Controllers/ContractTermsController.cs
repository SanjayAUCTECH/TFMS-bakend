using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContractTermsController : ControllerBase
{
    private readonly IContractTermRepository _repo;
    public ContractTermsController(IContractTermRepository repo) => _repo = repo;

    /// <summary>
    /// GET api/contractterms/{contractId}
    /// Get all terms & conditions for a contract (page 2 + page 3)
    /// </summary>
    [HttpGet("{contractId}")]
    public async Task<IActionResult> GetByContractId(string contractId)
    {
        var data = await _repo.GetByContractIdAsync(contractId);
        return Ok(ApiResponse<IEnumerable<ContractTermResponse>>.Ok(data, "Contract terms retrieved."));
    }

    /// <summary>
    /// POST api/contractterms
    /// Save (upsert) all terms for a contract — replaces existing terms
    /// Body: { "contractId": "CNT-000106", "terms": [{ "pageNo": 2, "termNo": 1, "termText": "..." }, ...] }
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Save([FromBody] SaveContractTermsRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ContractId))
            return BadRequest(ApiResponse<object>.Fail("ContractId is required."));

        var terms = request.Terms ?? new List<ContractTermItem>();
        var data = await _repo.SaveAsync(request.ContractId, terms);
        return Ok(ApiResponse<IEnumerable<ContractTermResponse>>.Ok(data, "Contract terms saved successfully."));
    }
}
