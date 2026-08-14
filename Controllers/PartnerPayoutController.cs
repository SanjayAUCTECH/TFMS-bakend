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
    /// GET api/PartnerPayout/monthly-payout-dates
    /// Returns all distinct payout periods saved in PartnerMonthlyPayout table.
    /// </summary>
    [HttpGet("monthly-payout-dates")]
    public async Task<IActionResult> GetMonthlyPayoutDates()
    {
        var r = await _service.GetMonthlyPayoutDatesAsync();
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// GET api/PartnerPayout/last-payout-date
    /// Returns last Date/ToDate/FromDate from PartnerMonthlyCampPayout table.
    /// </summary>
    [HttpGet("last-payout-date")]
    public async Task<IActionResult> GetLastPayoutDate()
    {
        var r = await _service.GetLastPayoutDateAsync();
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// GET api/PartnerPayout/last-monthly-payout-date
    /// Returns last Date/ToDate/FromDate from PartnerMonthlyPayout table.
    /// </summary>
    [HttpGet("last-monthly-payout-date")]
    public async Task<IActionResult> GetLastMonthlyPayoutDate()
    {
        var r = await _service.GetLastMonthlyPayoutDateAsync();
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// GET api/PartnerPayout/monthly-payout-list
    /// Get paginated partner monthly payout records.
    /// Optional filters: fromDate, toDate, pageNumber, pageSize
    /// </summary>
    [HttpGet("monthly-payout-list")]
    public async Task<IActionResult> GetMonthlyPayoutList([FromQuery] GetPartnerMonthlyPayoutListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.GetMonthlyPayoutListAsync(request);
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
    /// GET api/PartnerPayout/payout-by-month?fromDate=2026-07-01&amp;toDate=2026-07-31
    /// Partner-wise payout summary with camp breakdown for selected date range.
    /// Data comes from PartnerMonthlyCampPayout table.
    /// </summary>
    [HttpGet("payout-by-month")]
    public async Task<IActionResult> GetPartnerPayoutByMonth(
        [FromQuery] DateTime fromDate,
        [FromQuery] DateTime toDate)
    {
        var r = await _service.GetPartnerPayoutByMonthAsync(fromDate, toDate);
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
    /// GET api/PartnerPayout?fromDate=2026-01-01&amp;toDate=2026-01-31
    /// Returns camp-wise income/expense and partner share breakdown for the selected date range.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetPayoutData(
        [FromQuery] DateTime fromDate,
        [FromQuery] DateTime toDate)
    {
        var r = await _service.GetPayoutDataAsync(fromDate, toDate);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// POST api/PartnerPayout/release-payout
    /// Save a release payout for a partner into PartnerReleasePayout table.
    /// </summary>
    [HttpPost("release-payout")]
    public async Task<IActionResult> SaveReleasePayout([FromBody] CreatePartnerReleasePayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.SaveReleasePayoutAsync(request, CurrentUserId);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// DELETE api/PartnerPayout/delete-camp-payout
    /// Soft-delete PartnerMonthlyCampPayout records by ToDate only.
    /// Body: { "toDate": "2026-07-31" }
    /// </summary>
    [HttpDelete("delete-camp-payout")]
    public async Task<IActionResult> DeleteCampPayout([FromBody] DeletePartnerCampPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.DeleteCampPayoutAsync(request, CurrentUserId);
        return r.Success ? Ok(r) : BadRequest(r);
    }

    /// <summary>
    /// POST api/PartnerPayout/regenerate-camp-payout
    /// Delete existing camp payout by ToDate then regenerate fresh.
    /// </summary>
    [HttpPost("regenerate-camp-payout")]
    public async Task<IActionResult> RegenerateCampPayout([FromBody] SavePartnerMonthlyCampPayoutRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        // Step 1 — delete by ToDate (ignore if nothing deleted)
        var delReq = new DeletePartnerCampPayoutRequest { ToDate = request.ToDate };
        await _service.DeleteCampPayoutAsync(delReq, CurrentUserId);

        // Step 2 — save fresh
        var r = await _service.SaveMonthlyCampPayoutAsync(request, CurrentUserId);
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
