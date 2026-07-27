using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ExpensesController : BaseApiController
{
    private readonly IExpenseService _service;
    public ExpensesController(IExpenseService service, IActivityLogService log)
    { _service = service; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] ExpenseListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateExpenseRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.Expenses, $"Created Expense '{request.Head}' #{r.Data!.Id}", r.Data!.Id.ToString(), "Expense");
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateExpenseRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.Expenses, $"Updated Expense #{id}", id.ToString(), "Expense");
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.Expenses, $"Deleted Expense #{id}", id.ToString(), "Expense");
        return r.Success ? Ok(r) : NotFound(r);
    }
}
