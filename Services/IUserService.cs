using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IUserService
{
    Task<ApiResponse<IEnumerable<UserResponse>>> GetAllAsync(UserListRequest request);
    Task<ApiResponse<UserResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<UserResponse>>              CreateAsync(CreateUserRequest request);
    Task<ApiResponse<UserResponse>>              UpdateAsync(int id, UpdateUserRequest request);
    Task<ApiResponse<bool>>                      ChangePasswordAsync(int id, ChangePasswordRequest request);
    Task<ApiResponse<bool>>                      ResetPasswordAsync(int id, ResetPasswordRequest request);
    Task<ApiResponse<bool>>                      UpdateMenuAccessAsync(int id, UpdateMenuAccessRequest request);
    Task<ApiResponse<bool>>                      UpdateLoginAccessAsync(int id, UpdateLoginAccessRequest request);
    Task<ApiResponse<bool>>                      DeleteAsync(int id);
}
