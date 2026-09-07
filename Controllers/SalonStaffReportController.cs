using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SalonStaffReportController : BaseApiController
{
    private readonly ISalonStaffReportService _service;

    public SalonStaffReportController(
        ISalonStaffReportService service,
        IActivityLogService      log)
    {
        _service     = service;
        _activityLog = log;
    }

    /// <summary>
    /// GET /api/SalonStaffReport
    /// Filters: SalonId, StaffId, DateFrom, DateTo
    /// Returns: data (rows) + cards (summary) in single response
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetReport([FromQuery] SalonStaffReportRequest request)
    {
        var result = await _service.GetReportAsync(request);
        return Ok(result);
    }
}
