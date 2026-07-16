using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _service;
    public DashboardController(IDashboardService service) => _service = service;

    /// <summary>
    /// GET api/dashboard/stats
    /// Optional filters: ?campId=1 &amp;tenantId=2 &amp;month=2026-07
    /// All filters optional — omit for full dashboard
    /// </summary>
    [HttpGet("stats")]
    public async Task<IActionResult> GetStats(
        [FromQuery] int?    campId   = null,
        [FromQuery] int?    tenantId = null,
        [FromQuery] string? month    = null)   // format: "2026-07"
    {
        var result = await _service.GetStatsAsync(campId, tenantId, month);
        return Ok(result);
    }

    /// <summary>
    /// GET api/dashboard/staff-expiry-alerts
    /// Returns staff members whose documents are expired or expiring within daysAhead days (default 30).
    /// Alert clears automatically once expiry date is updated beyond daysAhead from today.
    /// </summary>
    [HttpGet("staff-expiry-alerts")]
    public async Task<IActionResult> GetStaffExpiryAlerts(
        [FromQuery] int daysAhead = 30)
    {
        var result = await _service.GetStaffExpiryAlertsAsync(daysAhead);
        return Ok(result);
    }

    /// <summary>
    /// GET api/dashboard/owner-payment-alerts
    /// Returns owner installments due within daysAhead days (default 2).
    /// Alert auto-clears when payment is marked Paid OR when DueDate passes.
    /// </summary>
    [HttpGet("owner-payment-alerts")]
    public async Task<IActionResult> GetOwnerPaymentAlerts(
        [FromQuery] int daysAhead = 2)
    {
        var result = await _service.GetOwnerPaymentAlertsAsync(daysAhead);
        return Ok(result);
    }

    /// <summary>
    /// GET api/dashboard/owner-month-summary
    /// Returns this month's owner payment summary — total due, paid, pending per owner.
    /// Optional: ?month=2026-07 to get any month's summary.
    /// </summary>
    [HttpGet("owner-month-summary")]
    public async Task<IActionResult> GetOwnerMonthSummary(
        [FromQuery] string? month = null)
    {
        var result = await _service.GetOwnerMonthSummaryAsync(month);
        return Ok(result);
    }

    /// <summary>GET api/dashboard/tenant-payment-alerts — due within daysAhead (default 2)</summary>
    [HttpGet("tenant-payment-alerts")]
    public async Task<IActionResult> GetTenantPaymentAlerts([FromQuery] int daysAhead = 2)
    {
        var result = await _service.GetTenantPaymentAlertsAsync(daysAhead);
        return Ok(result);
    }

    /// <summary>GET api/dashboard/tenant-month-summary — this month's collection summary</summary>
    [HttpGet("tenant-month-summary")]
    public async Task<IActionResult> GetTenantMonthSummary([FromQuery] string? month = null)
    {
        var result = await _service.GetTenantMonthSummaryAsync(month);
        return Ok(result);
    }
}
