using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class StaffService : IStaffService
{
    private readonly IStaffRepository _repo;
    public StaffService(IStaffRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<StaffResponse>>> GetAllAsync(StaffListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var cards = await _repo.GetStatsAsync();
        return ApiResponse<IEnumerable<StaffResponse>>.Ok(
            data.Select(ToResponse), "Staff retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize), cards);
    }

    public async Task<ApiResponse<StaffResponse>> GetByIdAsync(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item == null
            ? ApiResponse<StaffResponse>.Fail("Staff member not found.")
            : ApiResponse<StaffResponse>.Ok(ToResponse(item));
    }

    public async Task<ApiResponse<StaffResponse>> CreateAsync(CreateStaffRequest request)
    {
        if (await _repo.UsernameExistsAsync(request.Username?.Trim() ?? ""))
            return ApiResponse<StaffResponse>.Fail("Username already exists.");

        var staff = new Staff
        {
            Name        = request.Name?.Trim() ?? "",
            Contact     = request.Contact?.Trim() ?? "",
            Email       = request.Email?.Trim() ?? "",
            Address     = request.Address?.Trim() ?? "",
            Username    = request.Username?.Trim().ToLower() ?? "",
            Password    = request.Password,
            LoginAccess = request.LoginAccess,
            Status      = request.Status,
            Remarks     = request.Remarks?.Trim() ?? "",
        };

        var id = await _repo.CreateAsync(staff);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<StaffResponse>.Ok(ToResponse(created!), "Staff member created successfully.");
    }

    public async Task<ApiResponse<StaffResponse>> UpdateAsync(int id, UpdateStaffRequest request)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<StaffResponse>.Fail("Staff member not found.");

        if (await _repo.UsernameExistsAsync(request.Username?.Trim() ?? "", id))
            return ApiResponse<StaffResponse>.Fail("Username already taken by another staff member.");

        existing.Name        = request.Name?.Trim() ?? "";
        existing.Contact     = request.Contact?.Trim() ?? "";
        existing.Email       = request.Email?.Trim() ?? "";
        existing.Address     = request.Address?.Trim() ?? "";
        existing.Username    = request.Username?.Trim().ToLower() ?? "";
        existing.LoginAccess = request.LoginAccess;
        existing.Status      = request.Status;
        existing.Remarks     = request.Remarks?.Trim() ?? "";

        // Only update password if provided
        if (!string.IsNullOrWhiteSpace(request.Password))
            existing.Password = request.Password;

        await _repo.UpdateAsync(existing);
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<StaffResponse>.Ok(ToResponse(updated!), "Staff member updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id))
            return ApiResponse<bool>.Fail("Staff member not found.");
        return await _repo.DeleteAsync(id)
            ? ApiResponse<bool>.Ok(true, "Staff member deleted.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static StaffResponse ToResponse(Staff s) => new()
    {
        Id          = s.Id,
        StaffId     = s.StaffId,
        Name        = s.Name,
        Role        = s.Role,
        Contact     = s.Contact,
        Email       = s.Email,
        Address     = s.Address,
        Username    = s.Username,
        LoginAccess = s.LoginAccess,
        Status      = s.Status,
        Remarks     = s.Remarks,
        CreatedAt   = s.CreatedAt,
        UpdatedAt   = s.UpdatedAt,
    };
}
