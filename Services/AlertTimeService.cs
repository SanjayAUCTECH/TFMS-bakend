using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class AlertTimeService : IAlertTimeService
{
    private readonly IAlertTimeRepository _repo;

    public AlertTimeService(IAlertTimeRepository repo)
    {
        _repo = repo;
    }

    // ── Get All Alert Times ───────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<AlertTimeResponse>>> GetAllAsync(AlertTimeListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        
        var pagination = new PaginationMeta
        {
            TotalRecords = total,
            CurrentPage = request.ResolvedPageNumber,
            PageSize = request.ResolvedPageSize,
            TotalPages = (int)Math.Ceiling(total / (double)request.ResolvedPageSize),
            HasNextPage = request.ResolvedPageNumber < (int)Math.Ceiling(total / (double)request.ResolvedPageSize),
            HasPreviousPage = request.ResolvedPageNumber > 1
        };
        
        return ApiResponse<IEnumerable<AlertTimeResponse>>.Ok(
            data,
            "Alert times retrieved successfully.",
            pagination
        );
    }

    // ── Get Alert Time By ID ──────────────────────────────────────
    public async Task<ApiResponse<AlertTimeResponse>> GetByIdAsync(int id)
    {
        var alertTime = await _repo.GetByIdAsync(id);
        
        if (alertTime == null)
            return ApiResponse<AlertTimeResponse>.Fail("Alert time not found.");

        return ApiResponse<AlertTimeResponse>.Ok(alertTime, "Alert time retrieved successfully.");
    }

    // ── Create Alert Time ─────────────────────────────────────────
    public async Task<ApiResponse<AlertTimeResponse>> CreateAsync(CreateAlertTimeRequest request, int? userId)
    {
        var alertTime = await _repo.CreateAsync(request, userId);
        
        if (alertTime == null)
            return ApiResponse<AlertTimeResponse>.Fail("Alert name already exists.");

        return ApiResponse<AlertTimeResponse>.Ok(alertTime, "Alert time created successfully.");
    }

    // ── Update Alert Time ─────────────────────────────────────────
    public async Task<ApiResponse<AlertTimeResponse>> UpdateAsync(int id, UpdateAlertTimeRequest request, int? userId)
    {
        var alertTime = await _repo.UpdateAsync(id, request, userId);
        
        if (alertTime == null)
            return ApiResponse<AlertTimeResponse>.Fail("Alert time not found or alert name already exists.");

        return ApiResponse<AlertTimeResponse>.Ok(alertTime, "Alert time updated successfully.");
    }

    // ── Delete Alert Time ─────────────────────────────────────────
    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId)
    {
        var result = await _repo.DeleteAsync(id, userId);
        
        if (!result)
            return ApiResponse<bool>.Fail("Alert time not found.");

        return ApiResponse<bool>.Ok(true, "Alert time deleted successfully.");
    }
}
