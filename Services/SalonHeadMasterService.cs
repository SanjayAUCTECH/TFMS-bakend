using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonHeadMasterService : ISalonHeadMasterService
{
    private readonly ISalonHeadMasterRepository _repo;

    public SalonHeadMasterService(ISalonHeadMasterRepository repo) => _repo = repo;

    // ── GET ALL ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<SalonHeadMasterResponse>>> GetAllAsync(
        SalonHeadMasterListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);

        return ApiResponse<IEnumerable<SalonHeadMasterResponse>>.Ok(
            data.Select(ToResponse),
            "Salon heads retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    // ── GET ALL ACTIVE (dropdown) ──────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<SalonHeadMasterResponse>>> GetAllActiveAsync(
        string? headType = null)
    {
        var data = await _repo.GetAllActiveAsync(headType);
        return ApiResponse<IEnumerable<SalonHeadMasterResponse>>.Ok(
            data.Select(ToResponse),
            "Active salon heads retrieved successfully.");
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonHeadMasterResponse>> GetByIdAsync(int id)
    {
        var head = await _repo.GetByIdAsync(id);
        return head is null
            ? ApiResponse<SalonHeadMasterResponse>.Fail("Salon head not found.")
            : ApiResponse<SalonHeadMasterResponse>.Ok(ToResponse(head));
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonHeadMasterResponse>> CreateAsync(
        CreateSalonHeadMasterRequest request, int? userId = null)
    {
        var newId = await _repo.CreateAsync(new SalonHeadMaster
        {
            HeadType = request.HeadType.Trim(),
            HeadName = request.HeadName.Trim(),
            Status   = request.Status,
            AddedBy  = userId
        });

        var created = await _repo.GetByIdAsync(newId);
        return ApiResponse<SalonHeadMasterResponse>.Ok(
            ToResponse(created!), "Salon head created successfully.");
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonHeadMasterResponse>> UpdateAsync(
        int id, UpdateSalonHeadMasterRequest request, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<SalonHeadMasterResponse>.Fail("Salon head not found.");

        await _repo.UpdateAsync(new SalonHeadMaster
        {
            Id        = id,
            HeadType  = request.HeadType.Trim(),
            HeadName  = request.HeadName.Trim(),
            Status    = request.Status,
            UpdatedBy = userId
        });

        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<SalonHeadMasterResponse>.Ok(
            ToResponse(updated!), "Salon head updated successfully.");
    }

    // ── DELETE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Salon head not found.");

        var deleted = await _repo.DeleteAsync(id, userId);
        return deleted
            ? ApiResponse<bool>.Ok(true, "Salon head deleted successfully.")
            : ApiResponse<bool>.Fail("Delete operation failed.");
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static SalonHeadMasterResponse ToResponse(SalonHeadMaster h) => new()
    {
        Id        = h.Id,
        HeadType  = h.HeadType,
        HeadName  = h.HeadName,
        Status    = h.Status,
        CreatedAt = h.CreatedAt,
        UpdatedAt = h.UpdatedAt
    };
}
