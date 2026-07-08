using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReportsController : ControllerBase
{
    private readonly IReportService _service;
    public ReportsController(IReportService service) => _service = service;

    /// <summary>GET api/reports/inventory?CampId=1&Status=Occupied</summary>
    [HttpGet("inventory")]
    public async Task<IActionResult> Inventory([FromQuery] ReportRequest request)
        => Ok(await _service.GetInventoryReportAsync(request));

    /// <summary>GET api/reports/tenants?Status=Active&CampId=1</summary>
    [HttpGet("tenants")]
    public async Task<IActionResult> Tenants([FromQuery] ReportRequest request)
        => Ok(await _service.GetTenantReportAsync(request));

    /// <summary>GET api/reports/partners?Status=Active</summary>
    [HttpGet("partners")]
    public async Task<IActionResult> Partners([FromQuery] ReportRequest request)
        => Ok(await _service.GetPartnerReportAsync(request));

    /// <summary>GET api/reports/camps</summary>
    [HttpGet("camps")]
    public async Task<IActionResult> Camps([FromQuery] ReportRequest request)
        => Ok(await _service.GetCampReportAsync(request));

    /// <summary>GET api/reports/waivers?TenantId=1&DateFrom=2026-01-01&DateTo=2026-06-30</summary>
    [HttpGet("waivers")]
    public async Task<IActionResult> Waivers([FromQuery] ReportRequest request)
        => Ok(await _service.GetWaiverReportAsync(request));

    /// <summary>GET api/reports/tenant-ledger/{tenantId}?contractId=CNT-0001&dateFrom=2026-01-01</summary>
    [HttpGet("tenant-ledger/{tenantId:int}")]
    public async Task<IActionResult> TenantLedger(int tenantId,
        [FromQuery] string? contractId, [FromQuery] string? dateFrom, [FromQuery] string? dateTo)
    {
        var r = await _service.GetTenantLedgerAsync(tenantId, contractId, dateFrom, dateTo);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>GET api/reports/transactions?Month=June&Year=2026&CampId=1</summary>
    [HttpGet("transactions")]
    public async Task<IActionResult> Transactions([FromQuery] ReportRequest request)
        => Ok(await _service.GetTransactionStatementAsync(request));

    /// <summary>GET api/reports/due?TenantId=1&CampId=2&Month=2026-07</summary>
    [HttpGet("due")]
    public async Task<IActionResult> Due([FromQuery] ReportRequest request)
        => Ok(await _service.GetDueReportAsync(request));

    /// <summary>GET api/reports/room-history/{roomId}</summary>
    [HttpGet("room-history/{roomId:int}")]
    public async Task<IActionResult> RoomHistory(int roomId)
        => Ok(await _service.GetRoomHistoryAsync(roomId));

    /// <summary>GET api/reports/outgoing-payments?DateFrom=2026-01-01</summary>
    [HttpGet("outgoing-payments")]
    public async Task<IActionResult> OutgoingPayments([FromQuery] ReportRequest request)
        => Ok(await _service.GetOutgoingPaymentsAsync(request));

    /// <summary>POST api/reports/make-payment</summary>
    [HttpPost("make-payment")]
    public async Task<IActionResult> MakePayment([FromBody] MakePaymentRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.MakePaymentAsync(request);
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
