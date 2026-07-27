using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class DesignationService : IDesignationService
{
    private readonly IDesignationRepository _repo;
    public DesignationService(IDesignationRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<DesignationResponse>>> GetAllAsync(DesignationListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<DesignationResponse>>.Ok(
            data.Select(ToResponse), "Designations retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<DesignationResponse>>> GetAllActiveAsync()
        => ApiResponse<IEnumerable<DesignationResponse>>.Ok((await _repo.GetAllActiveAsync()).Select(ToResponse));

    public async Task<ApiResponse<DesignationResponse>> GetByIdAsync(int id)
    {
        var d = await _repo.GetByIdAsync(id);
        return d == null ? ApiResponse<DesignationResponse>.Fail("Not found.") : ApiResponse<DesignationResponse>.Ok(ToResponse(d));
    }

    public async Task<ApiResponse<DesignationResponse>> CreateAsync(CreateDesignationRequest request, int? userId = null)
    {
        var id = await _repo.CreateAsync(new Designation { Name = request.Name?.Trim() ?? "", Status = request.Status, AddedBy = userId });
        return ApiResponse<DesignationResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Designation created.");
    }

    public async Task<ApiResponse<DesignationResponse>> UpdateAsync(int id, UpdateDesignationRequest request, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<DesignationResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new Designation { Id = id, Name = request.Name.Trim(), Status = request.Status, UpdatedBy = userId });
        return ApiResponse<DesignationResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id, userId) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static DesignationResponse ToResponse(Designation d) => new()
    {
        Id = d.Id, Code = d.Code, Name = d.Name, Status = d.Status,
        CreatedAt = d.CreatedAt, UpdatedAt = d.UpdatedAt
    };
}
