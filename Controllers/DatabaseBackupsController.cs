using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DatabaseBackupsController : BaseApiController
{
    private readonly IDatabaseBackupRepository _repo;
    private readonly IDbConnectionFactory _factory;
    private readonly IConfiguration _config;

    public DatabaseBackupsController(
        IDatabaseBackupRepository repo,
        IDbConnectionFactory factory,
        IActivityLogService log,
        IConfiguration config)
    {
        _repo = repo;
        _factory = factory;
        _activityLog = log;
        _config = config;
    }

    /// <summary>
    /// POST api/databasebackups — Create database backup
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateBackup([FromBody] CreateBackupDto request)
    {
        if (string.IsNullOrWhiteSpace(request.BackupName))
            return BadRequest(ApiResponse<object>.Fail("BackupName is required."));

        if (string.IsNullOrWhiteSpace(request.Location))
            return BadRequest(ApiResponse<object>.Fail("Location is required."));

        try
        {
            // Generate backup file name (no timestamp needed - already in BackupName)
            var backupFileName = $"{request.BackupName}.bak";
            var backupFilePath = Path.Combine(request.Location, backupFileName);

            // Try to create directory on server (for SQL Server backup)
            // This is for cases where SQL Server and API are on the same machine
            try
            {
                if (!Directory.Exists(request.Location))
                {
                    Directory.CreateDirectory(request.Location);
                }
            }
            catch (UnauthorizedAccessException)
            {
                // Permission denied - SQL Server might still be able to write to its own paths
            }
            catch (Exception)
            {
                // Other errors - continue anyway, let SQL Server try
            }

            // Create backup and record (SQL Server will write to backup directory on SERVER)
            var id = await _repo.CreateBackupAsync(request, backupFilePath, CurrentUserName);
            
            await Log(
                ActivityType.Insert, 
                ActivityModule.DatabaseBackup, 
                $"Database backup '{request.BackupName}' created at {request.Location}", 
                id.ToString(), 
                "DatabaseBackup"
            );

            var backup = await _repo.GetByIdAsync(id);
            return Ok(ApiResponse<BackupListDto>.Ok(backup!, "Database backup created successfully on server."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to create database backup: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/databasebackups — Get all backups (paginated with search)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null)
    {
        if (pageNumber < 1) pageNumber = 1;
        if (pageSize < 1) pageSize = 10;

        try
        {
            var (backups, totalRecords) = await _repo.GetAllAsync(pageNumber, pageSize, search);
            var pagination = PaginationHelper.Build(totalRecords, pageNumber, pageSize);
            return Ok(ApiResponse<IEnumerable<BackupListDto>>.Ok(backups, "Database backups retrieved successfully.", pagination));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to retrieve database backups: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/databasebackups/{id} — Get backup by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        try
        {
            var backup = await _repo.GetByIdAsync(id);
            if (backup == null)
                return NotFound(ApiResponse<object>.Fail("Database backup not found."));

            return Ok(ApiResponse<BackupListDto>.Ok(backup, "Database backup retrieved successfully."));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to retrieve database backup: {ex.Message}"));
        }
    }

    /// <summary>
    /// GET api/databasebackups/{id}/download — Download backup file from server
    /// </summary>
    [HttpGet("{id}/download")]
    public async Task<IActionResult> DownloadBackup(int id)
    {
        try
        {
            var backup = await _repo.GetByIdAsync(id);
            if (backup == null)
                return NotFound(ApiResponse<object>.Fail("Database backup not found."));

            // Get backup file path
            var backupFileName = $"{backup.BackupName}.bak";
            var backupFilePath = Path.Combine(backup.Location, backupFileName);

            // Check if file exists on server
            if (!System.IO.File.Exists(backupFilePath))
            {
                return NotFound(ApiResponse<object>.Fail($"Backup file not found on server: {backupFilePath}"));
            }

            // Read file and return as download
            var fileBytes = await System.IO.File.ReadAllBytesAsync(backupFilePath);
            
            await Log(
                ActivityType.View, 
                ActivityModule.DatabaseBackup, 
                $"Downloaded backup file: {backup.BackupName}", 
                id.ToString(), 
                "DatabaseBackup"
            );

            return File(fileBytes, "application/octet-stream", backupFileName);
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail($"Failed to download backup file: {ex.Message}"));
        }
    }
}
