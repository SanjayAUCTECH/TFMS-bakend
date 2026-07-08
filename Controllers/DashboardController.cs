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
}
