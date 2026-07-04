using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class FloorService : IFloorService
{
    private readonly IFloorRepository _repo;
    public FloorService(IFloorRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<FloorResponse>>> GetAllAsync(FloorListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<FloorResponse>>.Ok(
            data.Select(ToResponse), "Floors retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<FloorResponse>>> GetAllActiveAsync()
        => ApiResponse<IEnumerable<FloorResponse>>.Ok((await _repo.GetAllActiveAsync()).Select(ToResponse));

    public async Task<ApiResponse<FloorResponse>> GetByIdAsync(int id)
    {
        var f = await _repo.GetByIdAsync(id);
        return f == null ? ApiResponse<FloorResponse>.Fail("Floor not found.") : ApiResponse<FloorResponse>.Ok(ToResponse(f));
    }

    public async Task<ApiResponse<FloorResponse>> CreateAsync(CreateFloorRequest request)
    {
        var id = await _repo.CreateAsync(new Floor { Name = request.Name.Trim(), Number = request.Number ?? 0, Status = request.Status });
        return ApiResponse<FloorResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Floor created.");
    }

    public async Task<ApiResponse<FloorResponse>> UpdateAsync(int id, UpdateFloorRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<FloorResponse>.Fail("Floor not found.");
        await _repo.UpdateAsync(new Floor { Id = id, Name = request.Name.Trim(), Number = request.Number ?? 0, Status = request.Status });
        return ApiResponse<FloorResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Floor updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Floor not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Floor deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static FloorResponse ToResponse(Floor f) => new()
    {
        Id = f.Id, Name = f.Name, Number = f.Number, Status = f.Status,
        CreatedAt = f.CreatedAt, UpdatedAt = f.UpdatedAt
    };
}
