using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonMasterService : ISalonMasterService
{
    private readonly ISalonMasterRepository _repo;

    public SalonMasterService(ISalonMasterRepository repo) => _repo = repo;

    // ── GET ALL ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<SalonMasterResponse>>> GetAllAsync(SalonMasterListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);

        return ApiResponse<IEnumerable<SalonMasterResponse>>.Ok(
            data.Select(ToResponse),
            "Salons retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonMasterResponse>> GetByIdAsync(int id)
    {
        var salon = await _repo.GetByIdAsync(id);
        return salon is null
            ? ApiResponse<SalonMasterResponse>.Fail("Salon not found.")
            : ApiResponse<SalonMasterResponse>.Ok(ToResponse(salon));
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonMasterResponse>> CreateAsync(CreateSalonMasterRequest request, int? userId = null)
    {
        var newId = await _repo.CreateAsync(new SalonMaster
        {
            Name           = request.Name?.Trim(),
            Address        = request.Address?.Trim(),
            Contact        = request.Contact?.Trim(),
            Description    = request.Description?.Trim(),
            ThumbnailImage = request.ThumbnailImage?.Trim(),
            Status         = request.Status ?? "Active",
            AddedBy        = userId
        });

        var created = await _repo.GetByIdAsync(newId);
        return ApiResponse<SalonMasterResponse>.Ok(ToResponse(created!), "Salon created successfully.");
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<SalonMasterResponse>> UpdateAsync(int id, UpdateSalonMasterRequest request, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing is null)
            return ApiResponse<SalonMasterResponse>.Fail("Salon not found.");

        await _repo.UpdateAsync(new SalonMaster
        {
            Id             = id,
            Name           = request.Name?.Trim(),
            Address        = request.Address?.Trim(),
            Contact        = request.Contact?.Trim(),
            Description    = request.Description?.Trim(),
            ThumbnailImage = request.ThumbnailImage?.Trim(),
            Status         = request.Status ?? "Active",
            UpdatedBy      = userId
        });

        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<SalonMasterResponse>.Ok(ToResponse(updated!), "Salon updated successfully.");
    }

    // ── DELETE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Salon not found.");

        var deleted = await _repo.DeleteAsync(id, userId);
        return deleted
            ? ApiResponse<bool>.Ok(true, "Salon deleted successfully.")
            : ApiResponse<bool>.Fail("Delete operation failed.");
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static SalonMasterResponse ToResponse(SalonMaster s) => new()
    {
        Id             = s.Id,
        Name           = s.Name,
        Address        = s.Address,
        Contact        = s.Contact,
        Description    = s.Description,
        ThumbnailImage = s.ThumbnailImage,
        Status         = s.Status,
        CreatedAt      = s.CreatedAt,
        UpdatedAt      = s.UpdatedAt
    };
}
