using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

// ── Request models for Swagger ────────────────────────────────────────────────
public class UploadFileRequest
{
    /// <summary>File to upload (image or PDF)</summary>
    public IFormFile File { get; set; } = null!;

    /// <summary>
    /// Cloudinary sub-folder inside TFMS_Software/.
    /// Examples: staff/emirates-id, staff/passport, owners/passport, general
    /// </summary>
    public string Folder { get; set; } = "general";
}

public class UploadMultipleFilesRequest
{
    /// <summary>Files to upload (images or PDFs)</summary>
    public List<IFormFile> Files { get; set; } = new();

    /// <summary>
    /// Cloudinary sub-folder inside TFMS_Software/.
    /// Examples: staff/emirates-id, owners/passport, general
    /// </summary>
    public string Folder { get; set; } = "general";
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
[Tags("Cloudinary")]
public class CloudinaryController : ControllerBase
{
    private readonly ICloudinaryService _cloudinary;
    public CloudinaryController(ICloudinaryService cloudinary) => _cloudinary = cloudinary;

    /// <summary>
    /// Upload a single file to Cloudinary.
    /// Supported: images (jpg, png, etc.) and PDF files.
    /// </summary>
    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Upload([FromForm] UploadFileRequest request)
    {
        if (request.File == null || request.File.Length == 0)
            return BadRequest(ApiResponse<object>.Fail("No file provided."));

        var url = await _cloudinary.UploadFileAsync(request.File, request.Folder);

        if (url == null)
            return StatusCode(500, ApiResponse<object>.Fail("Upload failed. Please try again."));

        return Ok(ApiResponse<object>.Ok(new
        {
            url,
            fileName    = request.File.FileName,
            size        = request.File.Length,
            contentType = request.File.ContentType,
            folder      = $"TFMS_Software/{request.Folder}"
        }, "File uploaded successfully."));
    }

    /// <summary>
    /// Upload multiple files to Cloudinary in one request.
    /// </summary>
    [HttpPost("upload-multiple")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadMultiple([FromForm] UploadMultipleFilesRequest request)
    {
        if (request.Files == null || request.Files.Count == 0)
            return BadRequest(ApiResponse<object>.Fail("No files provided."));

        var results = new List<object>();

        foreach (var file in request.Files)
        {
            if (file.Length == 0) continue;
            var url = await _cloudinary.UploadFileAsync(file, request.Folder);
            results.Add(new
            {
                fileName    = file.FileName,
                url         = url,
                size        = file.Length,
                contentType = file.ContentType,
                success     = url != null
            });
        }

        return Ok(ApiResponse<object>.Ok(new
        {
            uploaded = results.Count,
            folder   = $"TFMS_Software/{request.Folder}",
            files    = results
        }, $"{results.Count} file(s) uploaded successfully."));
    }
}
