using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CampbossesController : BaseApiController
{
    private readonly ICampbossRepository _repo;
    public CampbossesController(ICampbossRepository repo, IActivityLogService log)
    { _repo = repo; _activityLog = log; }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] CampbossListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var (data, total) = await _repo.GetAllAsync(request);
        return Ok(ApiResponse<IEnumerable<CampbossResponse>>.Ok(
            data.Select(ToResponse), "Campbosses retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize)));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var cb = await _repo.GetByIdAsync(id);
        return cb == null
            ? NotFound(ApiResponse<CampbossResponse>.Fail("Campboss not found."))
            : Ok(ApiResponse<CampbossResponse>.Ok(ToResponse(cb)));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCampbossRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var uname = request.Username?.Trim().ToLower();
        if (!string.IsNullOrWhiteSpace(uname) && await _repo.UsernameExistsAsync(uname))
            return BadRequest(ApiResponse<object>.Fail("Username already exists."));

        var cb = new Campboss
        {
            Name        = request.Name?.Trim() ?? "",
            Contact     = request.Contact?.Trim(),
            Email       = request.Email?.Trim(),
            Address     = request.Address?.Trim(),
            Username    = uname,
            Password    = request.Password ?? "Pass@123",
            LoginAccess = request.LoginAccess ?? "enabled",
            Status      = request.Status ?? "Active",
            Remarks     = request.Remarks?.Trim(),
            EmiratesId  = request.EmiratesId?.Trim(),
            PassportNo  = request.PassportNo?.Trim(),
            Nationality = request.Nationality?.Trim(),
            AddedBy     = CurrentUserId,
        };

        var id = await _repo.CreateAsync(cb);
        var created = await _repo.GetByIdAsync(id);
        await Log(ActivityType.Insert, "Campboss", $"Created Campboss #{id}", id.ToString(), "Campboss");
        return CreatedAtAction(nameof(GetById), new { id }, ApiResponse<CampbossResponse>.Ok(ToResponse(created!), "Campboss created."));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCampbossRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return NotFound(ApiResponse<object>.Fail("Campboss not found."));

        var uname = request.Username?.Trim().ToLower();
        if (!string.IsNullOrWhiteSpace(uname) && await _repo.UsernameExistsAsync(uname, id))
            return BadRequest(ApiResponse<object>.Fail("Username already taken."));

        existing.Name        = request.Name?.Trim() ?? "";
        existing.Contact     = request.Contact?.Trim();
        existing.Email       = request.Email?.Trim();
        existing.Address     = request.Address?.Trim();
        existing.Username    = uname ?? existing.Username;
        existing.LoginAccess = request.LoginAccess ?? "enabled";
        existing.Status      = request.Status ?? "Active";
        existing.Remarks     = request.Remarks?.Trim();
        existing.EmiratesId  = request.EmiratesId?.Trim();
        existing.PassportNo  = request.PassportNo?.Trim();
        existing.Nationality = request.Nationality?.Trim();
        existing.UpdatedBy   = CurrentUserId;

        if (!string.IsNullOrWhiteSpace(request.Password))
            existing.Password = request.Password;

        await _repo.UpdateAsync(existing);
        var updated = await _repo.GetByIdAsync(id);
        await Log(ActivityType.Update, "Campboss", $"Updated Campboss #{id}", id.ToString(), "Campboss");
        return Ok(ApiResponse<CampbossResponse>.Ok(ToResponse(updated!), "Campboss updated."));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        if (await _repo.GetByIdAsync(id) == null)
            return NotFound(ApiResponse<bool>.Fail("Campboss not found."));
        await _repo.DeleteAsync(id, CurrentUserId);
        await Log(ActivityType.Delete, "Campboss", $"Deleted Campboss #{id}", id.ToString(), "Campboss");
        return Ok(ApiResponse<bool>.Ok(true, "Campboss deleted."));
    }

    private static CampbossResponse ToResponse(Campboss cb) => new()
    {
        Id = cb.Id, CampbossId = cb.CampbossId, Name = cb.Name,
        Contact = cb.Contact, Email = cb.Email, Address = cb.Address,
        Username = cb.Username, LoginAccess = cb.LoginAccess, Status = cb.Status,
        Remarks = cb.Remarks, EmiratesId = cb.EmiratesId, PassportNo = cb.PassportNo,
        Nationality = cb.Nationality,
        AssignedCamps = cb.AssignedCamps.Select(ac => new CampbossAssignedCampResponse
        {
            Id = ac.Id, CampId = ac.CampId, CampName = ac.CampName,
            Type = ac.Type, Amount = ac.Amount
        }).ToList(),
        CreatedAt = cb.CreatedAt, UpdatedAt = cb.UpdatedAt,
    };
}
