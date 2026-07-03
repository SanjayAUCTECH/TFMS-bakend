using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IAuthService
{
    /// <summary>Authenticate user and return JWT token.</summary>
    Task<ApiResponse<LoginResponse>> LoginAsync(LoginRequest request);

    /// <summary>Get logged-in user's profile using userId from JWT claims.</summary>
    Task<ApiResponse<ProfileResponse>> GetProfileAsync(int userId);

    /// <summary>Update logged-in user's name, contact, email.</summary>
    Task<ApiResponse<ProfileResponse>> UpdateProfileAsync(int userId, UpdateProfileRequest request);

    /// <summary>Change password — requires current password verification.</summary>
    Task<ApiResponse<bool>> ChangePasswordAsync(int userId, ChangePasswordRequest request);

    /// <summary>Refresh JWT token — returns a new token if old one is still valid.</summary>
    Task<ApiResponse<LoginResponse>> RefreshTokenAsync(int userId);

    /// <summary>Update user's menu access permissions.</summary>
    Task<ApiResponse<bool>> UpdateMenuAccessAsync(int userId, UpdateMenuAccessRequest request);

    /// <summary>Logout — updates last logout time (stateless JWT, client discards token).</summary>
    Task<ApiResponse<bool>> LogoutAsync(int userId);
}
