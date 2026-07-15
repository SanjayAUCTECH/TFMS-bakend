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
        // Username check — sirf tab karo jab username diya ho (optional field)
        var uname = request.Username?.Trim().ToLower() ?? "";
        if (!string.IsNullOrWhiteSpace(uname) && await _repo.UsernameExistsAsync(uname))
            return ApiResponse<StaffResponse>.Fail("Username already exists. Please use a different username.");

        var staff = new Staff
        {
            Name        = request.Name?.Trim() ?? "",
            Designation = request.Designation?.Trim() ?? "",
            Contact     = request.Contact?.Trim() ?? "",
            Email       = request.Email?.Trim() ?? "",
            Address     = request.Address?.Trim() ?? "",
            Username    = request.Username?.Trim().ToLower() ?? "",
            Password    = request.Password,
            LoginAccess = request.LoginAccess,
            Status      = request.Status,
            Remarks     = request.Remarks?.Trim() ?? "",
            EmiratesId  = request.EmiratesId?.Trim() ?? "",
            PassportNo  = request.PassportNo?.Trim() ?? "",
            Nationality = request.Nationality?.Trim() ?? "",
            JobTitle    = request.JobTitle?.Trim() ?? "",
            MoveInDate  = string.IsNullOrWhiteSpace(request.MoveInDate) ? null : DateTime.Parse(request.MoveInDate),
            VisaExpiry  = string.IsNullOrWhiteSpace(request.VisaExpiry) ? null : DateTime.Parse(request.VisaExpiry),
        };

        var id = await _repo.CreateAsync(staff);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<StaffResponse>.Ok(ToResponse(created!), "Staff member created successfully.");
    }

    public async Task<ApiResponse<StaffResponse>> UpdateAsync(int id, UpdateStaffRequest request)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<StaffResponse>.Fail("Staff member not found.");

        // Username check — sirf tab karo jab username diya ho aur kisi aur ke paas na ho
        var uname2 = request.Username?.Trim().ToLower() ?? "";
        if (!string.IsNullOrWhiteSpace(uname2) && await _repo.UsernameExistsAsync(uname2, id))
            return ApiResponse<StaffResponse>.Fail("Username already taken by another staff member.");

        existing.Name        = request.Name?.Trim() ?? "";
        existing.Designation = request.Designation?.Trim() ?? "";
        existing.Contact     = request.Contact?.Trim() ?? "";
        existing.Email       = request.Email?.Trim() ?? "";
        existing.Address     = request.Address?.Trim() ?? "";
        existing.Username    = request.Username?.Trim().ToLower() ?? "";
        existing.LoginAccess = request.LoginAccess;
        existing.Status      = request.Status;
        existing.Remarks     = request.Remarks?.Trim() ?? "";
        existing.EmiratesId  = request.EmiratesId?.Trim() ?? "";
        existing.PassportNo  = request.PassportNo?.Trim() ?? "";
        existing.Nationality = request.Nationality?.Trim() ?? "";
        existing.JobTitle    = request.JobTitle?.Trim() ?? "";
        existing.MoveInDate  = string.IsNullOrWhiteSpace(request.MoveInDate) ? null : DateTime.Parse(request.MoveInDate);
        existing.VisaExpiry  = string.IsNullOrWhiteSpace(request.VisaExpiry) ? null : DateTime.Parse(request.VisaExpiry);

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
        Designation = s.Designation,
        Contact     = s.Contact,
        Email       = s.Email,
        Address     = s.Address,
        Username    = s.Username,
        LoginAccess = s.LoginAccess,
        Status      = s.Status,
        Remarks     = s.Remarks,
        EmiratesId  = s.EmiratesId,
        PassportNo  = s.PassportNo,
        Nationality = s.Nationality,
        JobTitle    = s.JobTitle,
        MoveInDate  = s.MoveInDate?.ToString("yyyy-MM-dd"),
        VisaExpiry  = s.VisaExpiry?.ToString("yyyy-MM-dd"),
        CreatedAt   = s.CreatedAt,
        UpdatedAt   = s.UpdatedAt,
    };
}
