using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class UserService : IUserService
{
    private readonly IUserRepository _repo;

    public UserService(IUserRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<UserResponse>>> GetAllAsync(UserListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<UserResponse>>.Ok(
            data.Select(ToResponse), "Users retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<UserResponse>> GetByIdAsync(int id)
    {
        var user = await _repo.GetByIdAsync(id);
        return user == null
            ? ApiResponse<UserResponse>.Fail("User not found.")
            : ApiResponse<UserResponse>.Ok(ToResponse(user));
    }

    public async Task<ApiResponse<UserResponse>> CreateAsync(CreateUserRequest request)
    {
        if (await _repo.UsernameExistsAsync(request.Username.Trim()))
            return ApiResponse<UserResponse>.Fail("Username already exists.");

        var user = new AppUser
        {
            Name         = request.Name.Trim(),
            Username     = request.Username.Trim().ToLower(),
            Password     = request.Password,   // stored as plain text
            Role         = request.Role.Trim(),
            Source       = request.Source.Trim(),
            SourceId     = request.SourceId,
            Contact      = request.Contact.Trim(),
            Email        = request.Email.Trim(),
            IsAdmin      = request.IsAdmin,
            LoginAccess  = request.LoginAccess,
            Status       = request.Status,
            MenuAccess   = request.MenuAccess,
        };

        var id = await _repo.CreateAsync(user);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<UserResponse>.Ok(ToResponse(created!), "User created successfully.");
    }

    public async Task<ApiResponse<UserResponse>> UpdateAsync(int id, UpdateUserRequest request)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<UserResponse>.Fail("User not found.");

        existing.Name        = request.Name.Trim();
        existing.Role        = request.Role.Trim();
        existing.Source      = request.Source.Trim();
        existing.SourceId    = request.SourceId;
        existing.Contact     = request.Contact.Trim();
        existing.Email       = request.Email.Trim();
        existing.IsAdmin     = request.IsAdmin;
        existing.LoginAccess = request.LoginAccess;
        existing.Status      = request.Status;
        existing.MenuAccess  = request.MenuAccess;

        await _repo.UpdateAsync(existing);
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<UserResponse>.Ok(ToResponse(updated!), "User updated successfully.");
    }

    public async Task<ApiResponse<bool>> ChangePasswordAsync(int id, ChangePasswordRequest request)
    {
        var user = await _repo.GetByIdAsync(id);
        if (user == null) return ApiResponse<bool>.Fail("User not found.");
        if (user.Password != request.CurrentPassword)
            return ApiResponse<bool>.Fail("Current password is incorrect.");

        await _repo.UpdatePasswordAsync(id, request.NewPassword);
        return ApiResponse<bool>.Ok(true, "Password changed successfully.");
    }

    public async Task<ApiResponse<bool>> ResetPasswordAsync(int id, ResetPasswordRequest request)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("User not found.");
        await _repo.UpdatePasswordAsync(id, request.NewPassword);
        return ApiResponse<bool>.Ok(true, "Password reset successfully.");
    }

    public async Task<ApiResponse<bool>> UpdateMenuAccessAsync(int id, UpdateMenuAccessRequest request)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("User not found.");
        await _repo.UpdateMenuAccessAsync(id, request.MenuAccess);
        return ApiResponse<bool>.Ok(true, "Menu access updated.");
    }

    public async Task<ApiResponse<bool>> UpdateLoginAccessAsync(int id, UpdateLoginAccessRequest request)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("User not found.");
        var access = request.LoginAccess == "enabled" ? "enabled" : "disabled";
        await _repo.UpdateLoginAccessAsync(id, access);
        return ApiResponse<bool>.Ok(true, $"Login access {access} successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("User not found.");
        return await _repo.DeleteAsync(id)
            ? ApiResponse<bool>.Ok(true, "User deleted.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static UserResponse ToResponse(AppUser u) => new()
    {
        Id          = u.Id,
        UserId      = u.UserId,
        Name        = u.Name,
        Username    = u.Username,
        Password    = u.Password,
        Role        = u.Role,
        Source      = u.Source,
        SourceId    = u.SourceId,
        Contact     = u.Contact,
        Email       = u.Email,
        IsAdmin     = u.IsAdmin,
        LoginAccess = u.LoginAccess,
        Status      = u.Status,
        MenuAccess  = u.MenuAccess,
        LastLogin   = u.LastLogin,
        CreatedAt   = u.CreatedAt,
        UpdatedAt   = u.UpdatedAt,
    };
}
