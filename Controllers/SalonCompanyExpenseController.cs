using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonCompanyExpenseController : BaseApiController
{
    private readonly ICompanyExpensePostingService _service;

    public SalonCompanyExpenseController(
        ICompanyExpensePostingService service,
        IActivityLogService           log)
    {
        _service     = service;
        _activityLog = log;
    }

    // ── GET /api/SalonCompanyExpense ──────────────────────────────────────────
    /// <summary>Get all company expense postings (paginated + filters)</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] CompanyExpensePostingListRequest request)
    {
        var result = await _service.GetAllAsync(request);
        return Ok(result);
    }

    // ── GET /api/SalonCompanyExpense/{id} ─────────────────────────────────────
    /// <summary>Get single company expense by ID</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);
        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── POST /api/SalonCompanyExpense ─────────────────────────────────────────
    /// <summary>Create a new company expense posting</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCompanyExpensePostingRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.CreateAsync(request, CurrentUserName);

        if (result.Success)
            await Log(ActivityType.Insert, ActivityModule.SalonMaster,
                $"Company expense created: {request.Type} | AED {request.Amount}",
                result.Data?.Id.ToString() ?? "", "CompanyExpensePosting");

        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── PUT /api/SalonCompanyExpense/{id} ─────────────────────────────────────
    /// <summary>Update an existing company expense posting</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCompanyExpensePostingRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var result = await _service.UpdateAsync(id, request, CurrentUserId);

        if (result.Success)
            await Log(ActivityType.Update, ActivityModule.SalonMaster,
                $"Company expense updated #{id}: {request.Type} | AED {request.Amount}",
                id.ToString(), "CompanyExpensePosting");

        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── DELETE /api/SalonCompanyExpense/{id} ──────────────────────────────────
    /// <summary>Soft-delete a company expense posting</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _service.DeleteAsync(id, CurrentUserName);

        if (result.Success)
            await Log(ActivityType.Delete, ActivityModule.SalonMaster,
                $"Company expense deleted #{id}",
                id.ToString(), "CompanyExpensePosting");

        return result.Success ? Ok(result) : NotFound(result);
    }

    // ── GET /api/SalonCompanyExpense/summary ──────────────────────────────────
    /// <summary>Get totals grouped by expense type</summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(
        [FromQuery] int?    salonId  = null,
        [FromQuery] string? dateFrom = null,
        [FromQuery] string? dateTo   = null)
    {
        var result = await _service.GetSummaryAsync(salonId, dateFrom, dateTo);
        return Ok(result);
    }
}
