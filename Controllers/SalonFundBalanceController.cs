using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SalonFundBalanceController : BaseApiController
{
    private readonly ISalonFundBalanceService _service;

    public SalonFundBalanceController(
        ISalonFundBalanceService service,
        IActivityLogService      log)
    {
        _service     = service;
        _activityLog = log;
    }

    // ── GET /api/SalonFundBalance ─────────────────────────────────────────────
    /// <summary>
    /// Salon Fund Balance Report
    ///
    /// Query Params: SalonId (optional), DateFrom (optional), DateTo (optional)
    ///
    /// Returns:
    ///   Staff:
    ///     - StaffPreviousMonthClosing  → All previous closings Staff share
    ///     - StaffCurrentClosing        → Latest closing Staff share (with date)
    ///     - TotalStaffShare            → Previous + Current
    ///     - StaffSalaryPaid            → Expense postings where Head = salary
    ///     - StaffClosingBalance        → TotalStaffShare - StaffSalaryPaid
    ///
    ///   Company:
    ///     - CompanyPreviousMonthClosing → All previous closings Company share
    ///     - CompanyCurrentClosing       → Latest closing Company share
    ///     - TotalCompanyRevenue         → Previous + Current
    ///     - CompanyExpense              → Expense postings (non-salary heads)
    ///     - CompanyClosingBalance       → TotalCompanyRevenue - CompanyExpense
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetBalance([FromQuery] SalonFundBalanceRequest request)
    {
        var result = await _service.GetBalanceAsync(request);
        return Ok(result);
    }
}
