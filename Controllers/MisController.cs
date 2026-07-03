using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MisController : ControllerBase
{
    private readonly IMisService _service;
    public MisController(IMisService service) => _service = service;

    /// <summary>
    /// GET api/mis/stats?CampId=1&Month=2026-06&PartnerId=2
    /// All filters optional — omit for all camps/months
    /// </summary>
    [HttpGet("stats")]
    public async Task<IActionResult> GetStats([FromQuery] MisRequest request)
        => Ok(await _service.GetMisStatsAsync(request));

    /// <summary>GET api/mis/owner-report?Status=Active</summary>
    [HttpGet("owner-report")]
    public async Task<IActionResult> OwnerReport([FromQuery] ReportRequest request)
        => Ok(await _service.GetOwnerReportAsync(request));
}
