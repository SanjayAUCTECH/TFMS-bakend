using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonStaffAssignService : ISalonStaffAssignService
{
    private readonly ISalonStaffAssignRepository _repo;

    public SalonStaffAssignService(ISalonStaffAssignRepository repo) => _repo = repo;

    // ── GET ALL ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<SalonStaffAssignResponse>>> GetAllAsync(
        SalonStaffAssignListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<SalonStaffAssignResponse>>.Ok(
            data.Select(ToResponse),
            "Salon staff assignments retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonStaffAssignResponse>> GetByIdAsync(int assignId)
    {
        var item = await _repo.GetByIdAsync(assignId);
        return item is null
            ? ApiResponse<SalonStaffAssignResponse>.Fail("Assignment not found.")
            : ApiResponse<SalonStaffAssignResponse>.Ok(ToResponse(item));
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonStaffAssignResponse>> CreateAsync(
        CreateSalonStaffAssignRequest request, int? userId = null)
    {
        var newId = await _repo.CreateAsync(new SalonStaffAssign
        {
            SalonId     = request.SalonId,
            StaffId     = request.StaffId,
            Percentage  = request.Percentage,
            Description = request.Description?.Trim(),
            Status      = request.Status,
            AddedBy     = userId
        });

        var created = await _repo.GetByIdAsync(newId);
        return ApiResponse<SalonStaffAssignResponse>.Ok(
            ToResponse(created!), "Assignment created successfully.");
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonStaffAssignResponse>> UpdateAsync(
        int assignId, UpdateSalonStaffAssignRequest request, int? userId = null)
    {
        if (await _repo.GetByIdAsync(assignId) is null)
            return ApiResponse<SalonStaffAssignResponse>.Fail("Assignment not found.");

        await _repo.UpdateAsync(new SalonStaffAssign
        {
            AssignId    = assignId,
            SalonId     = request.SalonId,
            StaffId     = request.StaffId,
            Percentage  = request.Percentage,
            Description = request.Description?.Trim(),
            Status      = request.Status,
            UpdatedBy   = userId
        });

        var updated = await _repo.GetByIdAsync(assignId);
        return ApiResponse<SalonStaffAssignResponse>.Ok(
            ToResponse(updated!), "Assignment updated successfully.");
    }

    // ── DELETE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> DeleteAsync(int assignId, int? userId = null)
    {
        // Directly delete — no pre-check needed (SP handles idempotent soft delete)
        await _repo.DeleteAsync(assignId, userId);
        return ApiResponse<bool>.Ok(true, "Assignment deleted successfully.");
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static SalonStaffAssignResponse ToResponse(SalonStaffAssign s) => new()
    {
        AssignId    = s.AssignId,
        SalonId     = s.SalonId,
        SalonName   = s.SalonName,
        StaffId     = s.StaffId,
        StaffName   = s.StaffName,
        Percentage  = s.Percentage,
        Description = s.Description,
        Status      = s.Status,
        CreatedAt   = s.CreatedAt,
        UpdatedAt   = s.UpdatedAt
    };
}
