using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class AuthService : IAuthService
{
    private readonly IDashboardRepository _dashRepo;
    private readonly IUserRepository      _userRepo;
    private readonly IConfiguration       _config;

    public AuthService(IDashboardRepository dashRepo, IUserRepository userRepo, IConfiguration config)
    {
        _dashRepo = dashRepo;
        _userRepo = userRepo;
        _config   = config;
    }

    // ── Login ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<LoginResponse>> LoginAsync(LoginRequest request)
    {
        var user = await _dashRepo.GetUserByUsernameAsync(request.Username.Trim().ToLower());
        if (user == null)
            return ApiResponse<LoginResponse>.Fail("Invalid username or password.");

        if (user.PasswordHash != request.Password)
            return ApiResponse<LoginResponse>.Fail("Invalid username or password.");

        if (user.Status != "Active")
            return ApiResponse<LoginResponse>.Fail("Your account is inactive. Please contact admin.");

        if (user.LoginAccess != "enabled")
            return ApiResponse<LoginResponse>.Fail("Login access is disabled for this account.");

        await _dashRepo.UpdateLastLoginAsync(user.Id);

        var token    = GenerateToken(user.Id, user.Username, user.Role, user.IsAdmin, user.UserId, out var expiresAt);

        return ApiResponse<LoginResponse>.Ok(new LoginResponse
        {
            Token      = token,
            UserId     = user.Id,
            UserCode   = user.UserId,
            Name       = user.Name,
            Username   = user.Username,
            Role       = user.Role,
            IsAdmin    = user.IsAdmin,
            MenuAccess = user.MenuAccess,
            Contact    = user.Contact,
            Email      = user.Email,
            Source     = user.Source,
            LastLogin  = user.LastLogin,
            ExpiresAt  = expiresAt,
        }, "Login successful.");
    }

    // ── Get Profile ───────────────────────────────────────────────────────────
    public async Task<ApiResponse<ProfileResponse>> GetProfileAsync(int userId)
    {
        var user = await _userRepo.GetByIdAsync(userId);
        if (user == null) return ApiResponse<ProfileResponse>.Fail("User not found.");

        return ApiResponse<ProfileResponse>.Ok(new ProfileResponse
        {
            Id          = user.Id,
            UserId      = user.UserId,
            Name        = user.Name,
            Username    = user.Username,
            Role        = user.Role,
            Source      = user.Source,
            Contact     = user.Contact,
            Email       = user.Email,
            IsAdmin     = user.IsAdmin,
            LoginAccess = user.LoginAccess,
            Status      = user.Status,
            MenuAccess  = user.MenuAccess,
            LastLogin   = user.LastLogin,
            CreatedAt   = user.CreatedAt,
        });
    }

    // ── Update Profile ────────────────────────────────────────────────────────
    public async Task<ApiResponse<ProfileResponse>> UpdateProfileAsync(int userId, UpdateProfileRequest request)
    {
        var user = await _userRepo.GetByIdAsync(userId);
        if (user == null) return ApiResponse<ProfileResponse>.Fail("User not found.");

        user.Name    = request.Name.Trim();
        user.Contact = request.Contact.Trim();
        user.Email   = request.Email.Trim();

        await _userRepo.UpdateAsync(user);
        var updated = await _userRepo.GetByIdAsync(userId);

        return ApiResponse<ProfileResponse>.Ok(new ProfileResponse
        {
            Id          = updated!.Id,
            UserId      = updated.UserId,
            Name        = updated.Name,
            Username    = updated.Username,
            Role        = updated.Role,
            Source      = updated.Source,
            Contact     = updated.Contact,
            Email       = updated.Email,
            IsAdmin     = updated.IsAdmin,
            LoginAccess = updated.LoginAccess,
            Status      = updated.Status,
            MenuAccess  = updated.MenuAccess,
            LastLogin   = updated.LastLogin,
            CreatedAt   = updated.CreatedAt,
        }, "Profile updated successfully.");
    }

    // ── Change Password ───────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> ChangePasswordAsync(int userId, ChangePasswordRequest request)
    {
        if (request.NewPassword != request.ConfirmPassword)
            return ApiResponse<bool>.Fail("New password and confirm password do not match.");

        var user = await _userRepo.GetByIdAsync(userId);
        if (user == null) return ApiResponse<bool>.Fail("User not found.");

        if (user.PasswordHash != request.CurrentPassword)
            return ApiResponse<bool>.Fail("Current password is incorrect.");

        if (request.NewPassword == request.CurrentPassword)
            return ApiResponse<bool>.Fail("New password must be different from current password.");

        await _userRepo.UpdatePasswordAsync(userId, request.NewPassword);
        return ApiResponse<bool>.Ok(true, "Password changed successfully.");
    }

    // ── Refresh Token ─────────────────────────────────────────────────────────
    public async Task<ApiResponse<LoginResponse>> RefreshTokenAsync(int userId)
    {
        var user = await _userRepo.GetByIdAsync(userId);
        if (user == null) return ApiResponse<LoginResponse>.Fail("User not found.");

        if (user.Status != "Active")
            return ApiResponse<LoginResponse>.Fail("Account is inactive.");

        if (user.LoginAccess != "enabled")
            return ApiResponse<LoginResponse>.Fail("Login access is disabled.");

        var token = GenerateToken(user.Id, user.Username, user.Role, user.IsAdmin, user.UserId, out var expiresAt);

        return ApiResponse<LoginResponse>.Ok(new LoginResponse
        {
            Token      = token,
            UserId     = user.Id,
            UserCode   = user.UserId,
            Name       = user.Name,
            Username   = user.Username,
            Role       = user.Role,
            IsAdmin    = user.IsAdmin,
            MenuAccess = user.MenuAccess,
            Contact    = user.Contact,
            Email      = user.Email,
            Source     = user.Source,
            LastLogin  = user.LastLogin,
            ExpiresAt  = expiresAt,
        }, "Token refreshed successfully.");
    }

    // ── Update Menu Access ────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> UpdateMenuAccessAsync(int userId, UpdateMenuAccessRequest request)
    {
        if (!await IsUserExistsAsync(userId))
            return ApiResponse<bool>.Fail("User not found.");

        await _userRepo.UpdateMenuAccessAsync(userId, request.MenuAccess);
        return ApiResponse<bool>.Ok(true, "Menu access updated successfully.");
    }

    // ── Logout ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> LogoutAsync(int userId)
    {
        // JWT is stateless — client discards the token
        // We just update last login time as last active timestamp
        await _dashRepo.UpdateLastLoginAsync(userId);
        return ApiResponse<bool>.Ok(true, "Logged out successfully.");
    }

    // ── Private: Generate JWT ─────────────────────────────────────────────────
    private string GenerateToken(int id, string username, string role, bool isAdmin,
        string userCode, out DateTime expiresAt)
    {
        var expiryHours = int.TryParse(_config["Jwt:ExpiryHours"], out var h) ? h : 876000;
        expiresAt = DateTime.UtcNow.AddHours(expiryHours); // ~100 years — effectively never expires

        var key   = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, id.ToString()),
            new Claim(ClaimTypes.Name,           username),
            new Claim(ClaimTypes.Role,           role),
            new Claim("IsAdmin",                 isAdmin.ToString()),
            new Claim("UserId",                  userCode),
        };

        var token = new JwtSecurityToken(
            issuer:             _config["Jwt:Issuer"],
            audience:           _config["Jwt:Audience"],
            claims:             claims,
            expires:            expiresAt,
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private async Task<bool> IsUserExistsAsync(int userId)
        => await _userRepo.ExistsAsync(userId);
}
