using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PartnerPayoutController : BaseApiController
{
    private readonly IPartnerPayoutService _service;

    public PartnerPayoutController(IPartnerPayoutService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    /// <summary>
    /// GET api/PartnerPayout/monthly-payout-list?month=6&amp;year=2026
    /// Get saved partner monthly payout records from PartnerMonthlyPayout table.
    /// Optional: pass partnerId to filter by specific partner.
    /// </summary>
    [HttpGet("monthly-payout-list")]
    public async Task<IActionResult> GetMonthlyPayoutList(
        [FromQuery] int month,
        [FromQuery] int year,
        [FromQuery] int? partnerId = null)
    {
        var r = await _service.GetMonthlyPayoutListAsync(month, year, partnerId);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// POST api/PartnerPayout/save-monthly-payout
    /// Save partner-wise monthly totals into PartnerMonthlyPayout table.
    /// </summary>
    [HttpPost("save-monthly-payout")]
    public async Task<IActionResult> SaveMonthlyPayout([FromBody] SavePartnerMonthlyPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.SaveMonthlyPayoutAsync(request, CurrentUserId);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// DELETE api/PartnerPayout/delete-monthly-payout
    /// Soft-delete partner monthly payout records by month/year.
    /// Pass partnerId to delete a specific partner, or omit to delete all partners for that month.
    /// </summary>
    [HttpDelete("delete-monthly-payout")]
    public async Task<IActionResult> DeleteMonthlyPayout([FromBody] DeletePartnerMonthlyPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.DeleteMonthlyPayoutAsync(request, CurrentUserId);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// GET api/PartnerPayout/payout-by-month?month=6&amp;year=2026
    /// Partner-wise payout summary with camp breakdown for selected month.
    /// Data comes from PartnerMonthlyCampPayout table.
    /// </summary>
    [HttpGet("payout-by-month")]
    public async Task<IActionResult> GetPartnerPayoutByMonth([FromQuery] int month, [FromQuery] int year)
    {
        var r = await _service.GetPartnerPayoutByMonthAsync(month, year);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// GET api/PartnerPayout/camp-payout-list
    /// Get saved records from PartnerMonthlyCampPayout table.
    /// Query params: partnerId, fromDate, toDate, pageNumber, pageSize
    /// </summary>
    [HttpGet("camp-payout-list")]
    public async Task<IActionResult> GetCampPayoutList([FromQuery] GetPartnerMonthlyCampPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.GetMonthlyCampPayoutAsync(request);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// GET api/PartnerPayout?month=6&amp;year=2026
    /// Returns camp-wise income/expense and partner share breakdown for the selected month.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetPayoutData([FromQuery] int month, [FromQuery] int year)
    {
        var r = await _service.GetPayoutDataAsync(month, year);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// POST api/PartnerPayout/generate-camp-payout
    /// Saves camp-wise payout rows into PartnerMonthlyCampPayout table.
    /// </summary>
    [HttpPost("generate-camp-payout")]
    public async Task<IActionResult> SaveCampPayout([FromBody] SavePartnerMonthlyCampPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.SaveMonthlyCampPayoutAsync(request, CurrentUserId);
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
