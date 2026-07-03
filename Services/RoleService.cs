using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class RoleService : IRoleService
{
    private readonly IRoleRepository _repo;
    public RoleService(IRoleRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<RoleResponse>>> GetAllAsync(RoleListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<RoleResponse>>.Ok(
            data.Select(ToResponse), "Roles retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<RoleResponse>>> GetAllActiveAsync()
        => ApiResponse<IEnumerable<RoleResponse>>.Ok((await _repo.GetAllActiveAsync()).Select(ToResponse));

    public async Task<ApiResponse<RoleResponse>> GetByIdAsync(int id)
    {
        var r = await _repo.GetByIdAsync(id);
        return r == null ? ApiResponse<RoleResponse>.Fail("Not found.") : ApiResponse<RoleResponse>.Ok(ToResponse(r));
    }

    public async Task<ApiResponse<RoleResponse>> CreateAsync(CreateRoleRequest request)
    {
        var id = await _repo.CreateAsync(new Role { RoleName = request.RoleName.Trim(), Status = request.Status });
        return ApiResponse<RoleResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Role created.");
    }

    public async Task<ApiResponse<RoleResponse>> UpdateAsync(int id, UpdateRoleRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<RoleResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new Role { Id = id, RoleName = request.RoleName.Trim(), Status = request.Status });
        return ApiResponse<RoleResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static RoleResponse ToResponse(Role r) => new()
    {
        Id = r.Id, RoleCode = r.RoleCode, RoleName = r.RoleName,
        Status = r.Status, CreatedAt = r.CreatedAt, UpdatedAt = r.UpdatedAt
    };
}
