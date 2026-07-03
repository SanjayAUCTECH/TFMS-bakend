using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentModesController : ControllerBase
{
    private readonly IPaymentModeService _service;
    public PaymentModesController(IPaymentModeService service) => _service = service;

    /// <summary>GET api/paymentmodes?status=Active</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status = null) => Ok(await _service.GetAllAsync(status));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) { var r = await _service.GetByIdAsync(id); return r.Success ? Ok(r) : NotFound(r); }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreatePaymentModeRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdatePaymentModeRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id) { var r = await _service.DeleteAsync(id); return r.Success ? Ok(r) : NotFound(r); }
}
