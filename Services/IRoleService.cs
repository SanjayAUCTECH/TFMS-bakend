using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IRoleService
{
    Task<ApiResponse<IEnumerable<RoleResponse>>> GetAllAsync(RoleListRequest request);
    Task<ApiResponse<IEnumerable<RoleResponse>>> GetAllActiveAsync();
    Task<ApiResponse<RoleResponse>> GetByIdAsync(int id);
    Task<ApiResponse<RoleResponse>> CreateAsync(CreateRoleRequest request);
    Task<ApiResponse<RoleResponse>> UpdateAsync(int id, UpdateRoleRequest request);
    Task<ApiResponse<bool>>         DeleteAsync(int id);
}
