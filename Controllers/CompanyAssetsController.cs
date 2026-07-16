using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;
using TFMS_software_api.Common;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CompanyAssetsController : ControllerBase
{
    private readonly ICompanyAssetRepository _repo;
    private readonly ICloudinaryService      _cloudinary;

    public CompanyAssetsController(ICompanyAssetRepository repo, ICloudinaryService cloudinary)
    {
        _repo       = repo;
        _cloudinary = cloudinary;
    }

    /// <summary>GET api/companyassets?PageNumber=1&amp;PageSize=20&amp;SearchText=&amp;Status=Active</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] CompanyAssetListRequest req)
    {
        var (data, total) = await _repo.GetAllAsync(req);
        return Ok(ApiResponse<IEnumerable<CompanyAssetResponse>>.Ok(
            data, "Company assets retrieved.",
            PaginationHelper.Build(total, req.ResolvedPageNumber, req.ResolvedPageSize)));
    }

    /// <summary>GET api/companyassets/5</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item == null
            ? NotFound(ApiResponse<object>.Fail("Asset not found."))
            : Ok(ApiResponse<CompanyAssetResponse>.Ok(item));
    }

    /// <summary>POST api/companyassets — multipart/form-data</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreateCompanyAssetRequest req)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        string? docUrl = req.DocumentUrl;
        if (req.Document != null)
        {
            var uploadedUrl = await _cloudinary.UploadFileAsync(req.Document, "company-assets");
            // Append uploaded URL to existing URLs (comma-separated)
            docUrl = string.IsNullOrWhiteSpace(docUrl) ? uploadedUrl : $"{docUrl},{uploadedUrl}";
        }
        var newId = await _repo.CreateAsync(req, docUrl);
        var created = await _repo.GetByIdAsync(newId);
        return CreatedAtAction(nameof(GetById), new { id = newId },
            ApiResponse<CompanyAssetResponse>.Ok(created!, "Asset created successfully."));
    }

    /// <summary>PUT api/companyassets/5 — multipart/form-data</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromForm] UpdateCompanyAssetRequest req)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        if (!await _repo.ExistsAsync(id))
            return NotFound(ApiResponse<object>.Fail("Asset not found."));
        string? docUrl = req.DocumentUrl;
        if (req.Document != null)
        {
            var uploadedUrl = await _cloudinary.UploadFileAsync(req.Document, "company-assets");
            // Append uploaded URL to existing URLs (comma-separated)
            docUrl = string.IsNullOrWhiteSpace(docUrl) ? uploadedUrl : $"{docUrl},{uploadedUrl}";
        }
        await _repo.UpdateAsync(id, req, docUrl);
        var updated = await _repo.GetByIdAsync(id);
        return Ok(ApiResponse<CompanyAssetResponse>.Ok(updated!, "Asset updated successfully."));
    }

    /// <summary>DELETE api/companyassets/5</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        if (!await _repo.ExistsAsync(id))
            return NotFound(ApiResponse<object>.Fail("Asset not found."));
        await _repo.DeleteAsync(id);
        return Ok(ApiResponse<bool>.Ok(true, "Asset deleted."));
    }
}
