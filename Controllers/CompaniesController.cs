using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CompaniesController : BaseApiController
{
    private readonly ICompanyRepository _repo;

    public CompaniesController(ICompanyRepository repo, IActivityLogService log)
    {
        _repo = repo;
        _activityLog = log;
    }

    /// <summary>
    /// POST api/companies — Create new company
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCompanyRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CompanyName))
            return BadRequest(ApiResponse<object>.Fail("CompanyName is required."));

        try
        {
            var id = await _repo.CreateAsync(request, CurrentUserName);
            await Log(ActivityType.Insert, ActivityModule.Companies, $"Company '{request.CompanyName}' created", id.ToString(), "Company");

            var company = await _repo.GetByIdAsync(id);
            return Ok(ApiResponse<CompanyResponse>.Ok(company!, "Company created successfully."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to create company: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/companies — Get all companies (paginated with filters)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 50,
        [FromQuery] string? search = null,
        [FromQuery] string? status = null)
    {
        var (companies, totalRecords) = await _repo.GetAllAsync(pageNumber, pageSize, search, status);
        var pagination = PaginationHelper.Build(totalRecords, pageNumber, pageSize);
        return Ok(ApiResponse<IEnumerable<CompanyResponse>>.Ok(companies, "Companies retrieved.", pagination));
    }

    /// <summary>
    /// GET api/companies/{id} — Get company by Id
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var company = await _repo.GetByIdAsync(id);
        if (company == null)
            return NotFound(ApiResponse<object>.Fail("Company not found."));

        return Ok(ApiResponse<CompanyResponse>.Ok(company, "Company retrieved."));
    }

    /// <summary>
    /// PUT api/companies/{id} — Update existing company
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCompanyRequest request)
    {
        try
        {
            await _repo.UpdateAsync(id, request, CurrentUserName);
            await Log(ActivityType.Update, ActivityModule.Companies, $"Company Id {id} updated", id.ToString(), "Company");

            var company = await _repo.GetByIdAsync(id);
            return Ok(ApiResponse<CompanyResponse>.Ok(company!, "Company updated successfully."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to update company: {ex.Message}"));
        }
    }

    /// <summary>
    /// DELETE api/companies/{id} — Soft delete company
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        try
        {
            await _repo.DeleteAsync(id, CurrentUserName);
            await Log(ActivityType.Delete, ActivityModule.Companies, $"Company Id {id} deleted", id.ToString(), "Company");

            return Ok(ApiResponse<object>.Ok(null, "Company deleted successfully."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to delete company: {ex.Message}"));
        }
    }
}
