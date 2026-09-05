using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SalonExpenseReportController : BaseApiController
{
    private readonly ISalonExpenseReportService _service;

    public SalonExpenseReportController(
        ISalonExpenseReportService service,
        IActivityLogService        log)
    {
        _service     = service;
        _activityLog = log;
    }

    // ── GET /api/SalonExpenseReport ───────────────────────────────────────────
    /// <summary>
    /// Salon Expense Report
    /// Returns detail rows in 'data' + summary cards in 'cards'
    ///
    /// Filters: DateFrom, DateTo, Head
    /// FundType: Head='salary' → RecipientName (Staff) | other → "Company"
    ///
    /// cards: { totalStaffFund, totalCompanyFund, grandTotal, totalEntries }
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetReport([FromQuery] SalonExpenseReportRequest request)
    {
        var result = await _service.GetReportAsync(request);
        return Ok(result);
    }
}
