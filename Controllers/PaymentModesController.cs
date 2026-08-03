using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentModesController : BaseApiController
{
    private readonly IPaymentModeService _service;
    public PaymentModesController(IPaymentModeService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    /// <summary>GET api/paymentmodes?status=Active&amp;searchText=cash</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status = null, [FromQuery] string? searchText = null)
    {
        var result = await _service.GetAllAsync(status);
        if (!result.Success) return Ok(result);

        if (!string.IsNullOrWhiteSpace(searchText))
        {
            var search = searchText.Trim().ToLower();
            var filtered = result.Data!.Where(r => r.Name.ToLower().Contains(search));
            return Ok(Common.ApiResponse<IEnumerable<PaymentModeResponse>>.Ok(filtered, result.Message));
        }
        return Ok(result);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreatePaymentModeRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.PaymentModes, $"Created PaymentMode #{r.Data!.Id}", r.Data!.Id.ToString(), "PaymentMode");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdatePaymentModeRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.PaymentModes, $"Updated PaymentMode #{id}", id.ToString(), "PaymentMode");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.PaymentModes, $"Deleted PaymentMode #{id}", id.ToString(), "PaymentMode");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
