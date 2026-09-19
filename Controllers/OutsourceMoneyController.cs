using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OutsourceMoneyController : BaseApiController
{
    private readonly IOutsourceMoneyService _service;

    public OutsourceMoneyController(
        IOutsourceMoneyService service,
        IActivityLogService activityLog)
    {
        _service = service;
        _activityLog = activityLog;
    }

    /// <summary>
    /// Get all Outsource Money records with pagination and filters
    /// </summary>
    [HttpGet]
    [SwaggerOperation(Summary = "Get all Outsource Money records", Description = "Retrieve paginated list of outsource money records with optional filters")]
    public async Task<IActionResult> GetAll([FromQuery] OutsourceMoneyListRequest request)
    {
        var result = await _service.GetAllAsync(request);

        await Log(
            activityType: "View",
            module: "OutsourceMoney",
            action: $"Viewed Outsource Money list (Page {request.ResolvedPageNumber})",
            status: "Success"
        );

        return Ok(result);
    }

    /// <summary>
    /// Get Outsource Money record by ID
    /// </summary>
    [HttpGet("{id}")]
    [SwaggerOperation(Summary = "Get Outsource Money by ID", Description = "Retrieve a specific outsource money record by its ID")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);

        await Log(
            activityType: "View",
            module: "OutsourceMoney",
            action: $"Viewed Outsource Money record #{id}",
            entityId: id.ToString(),
            entityType: "OutsourceMoney",
            status: result.Success ? "Success" : "Failed"
        );

        return result.Success ? Ok(result) : NotFound(result);
    }

    /// <summary>
    /// Create new Outsource Money record
    /// </summary>
    [HttpPost]
    [SwaggerOperation(Summary = "Create Outsource Money", Description = "Create a new outsource money record")]
    public async Task<IActionResult> Create([FromBody] CreateOutsourceMoneyRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var result = await _service.CreateAsync(request, CurrentUserId);

        if (result.Success)
        {
            await Log(
                activityType: "Create",
                module: "OutsourceMoney",
                action: $"Created Outsource Money record - Amount: {request.Amount:N2}, Purpose: {request.Purpose}",
                entityId: result.Data?.Id.ToString() ?? "",
                entityType: "OutsourceMoney",
                newValues: request,
                status: "Success"
            );
        }

        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Update existing Outsource Money record
    /// </summary>
    [HttpPut("{id}")]
    [SwaggerOperation(Summary = "Update Outsource Money", Description = "Update an existing outsource money record")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateOutsourceMoneyRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var oldRecord = await _service.GetByIdAsync(id);
        var result = await _service.UpdateAsync(id, request, CurrentUserId);

        if (result.Success)
        {
            await Log(
                activityType: "Update",
                module: "OutsourceMoney",
                action: $"Updated Outsource Money record #{id}",
                entityId: id.ToString(),
                entityType: "OutsourceMoney",
                oldValues: oldRecord.Data,
                newValues: request,
                status: "Success"
            );
        }

        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Delete Outsource Money record
    /// </summary>
    [HttpDelete("{id}")]
    [SwaggerOperation(Summary = "Delete Outsource Money", Description = "Soft delete an outsource money record")]
    public async Task<IActionResult> Delete(int id)
    {
        var oldRecord = await _service.GetByIdAsync(id);
        var result = await _service.DeleteAsync(id, CurrentUserId);

        await Log(
            activityType: "Delete",
            module: "OutsourceMoney",
            action: $"Deleted Outsource Money record #{id}",
            entityId: id.ToString(),
            entityType: "OutsourceMoney",
            oldValues: oldRecord.Data,
            status: result.Success ? "Success" : "Failed",
            error: result.Success ? null : result.Message
        );

        return result.Success ? Ok(result) : BadRequest(result);
    }
}
