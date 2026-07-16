using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class StaffController : ControllerBase
{
    private readonly IStaffService      _service;
    private readonly ICloudinaryService _cloudinary;

    public StaffController(IStaffService service, ICloudinaryService cloudinary)
    {
        _service    = service;
        _cloudinary = cloudinary;
    }

    /// <summary>GET api/staff?Status=Active&amp;SearchText=john</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] StaffListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    /// <summary>GET api/staff/5</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var r = await _service.GetByIdAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>POST api/staff — multipart/form-data with optional document files</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreateStaffRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        await UploadDocuments(request);
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    /// <summary>PUT api/staff/5 — multipart/form-data with optional document files</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromForm] UpdateStaffRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        await UploadDocuments(request);
        var r = await _service.UpdateAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    /// <summary>DELETE api/staff/5</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var r = await _service.DeleteAsync(id);
        return r.Success ? Ok(r) : NotFound(r);
    }

    // ── Upload all document files to Cloudinary and set URL properties ────────

    private async Task UploadDocuments(CreateStaffRequest req)
    {
        if (req.EmiratesIdDocument != null)
            req.EmiratesIdDocumentUrl = await _cloudinary.UploadFileAsync(req.EmiratesIdDocument, "staff/emirates-id");
        if (req.PassportDocument != null)
            req.PassportDocumentUrl = await _cloudinary.UploadFileAsync(req.PassportDocument, "staff/passport");
        if (req.LabourCardDocument != null)
            req.LabourCardDocumentUrl = await _cloudinary.UploadFileAsync(req.LabourCardDocument, "staff/labour-card");
        if (req.IloeDocument != null)
            req.IloeDocumentUrl = await _cloudinary.UploadFileAsync(req.IloeDocument, "staff/iloe");
        if (req.InsuranceDocument != null)
            req.InsuranceDocumentUrl = await _cloudinary.UploadFileAsync(req.InsuranceDocument, "staff/insurance");
    }

    private async Task UploadDocuments(UpdateStaffRequest req)
    {
        if (req.EmiratesIdDocument != null)
            req.EmiratesIdDocumentUrl = await _cloudinary.UploadFileAsync(req.EmiratesIdDocument, "staff/emirates-id");
        if (req.PassportDocument != null)
            req.PassportDocumentUrl = await _cloudinary.UploadFileAsync(req.PassportDocument, "staff/passport");
        if (req.LabourCardDocument != null)
            req.LabourCardDocumentUrl = await _cloudinary.UploadFileAsync(req.LabourCardDocument, "staff/labour-card");
        if (req.IloeDocument != null)
            req.IloeDocumentUrl = await _cloudinary.UploadFileAsync(req.IloeDocument, "staff/iloe");
        if (req.InsuranceDocument != null)
            req.InsuranceDocumentUrl = await _cloudinary.UploadFileAsync(req.InsuranceDocument, "staff/insurance");
    }
}
