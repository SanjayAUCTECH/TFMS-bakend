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
            Username    = uname,
            Password    = request.Password ?? "Pass@123",
            LoginAccess = request.LoginAccess ?? "enabled",
            Status      = request.Status ?? "Active",
            Remarks     = request.Remarks?.Trim() ?? "",
            EmiratesId  = request.EmiratesId?.Trim() ?? "",
            PassportNo  = request.PassportNo?.Trim() ?? "",
            Nationality = request.Nationality?.Trim() ?? "",
            JobTitle    = request.JobTitle?.Trim() ?? "",
            MoveInDate  = ParseDate(request.MoveInDate),
            VisaExpiry  = ParseDate(request.VisaExpiry),

            // Document dates
            EmiratesIdIssueDate  = ParseDate(request.EmiratesIdIssueDate),
            EmiratesIdExpiryDate = ParseDate(request.EmiratesIdExpiryDate),
            PassportIssueDate    = ParseDate(request.PassportIssueDate),
            PassportExpiryDate   = ParseDate(request.PassportExpiryDate),
            LabourCardIssueDate  = ParseDate(request.LabourCardIssueDate),
            LabourCardExpiryDate = ParseDate(request.LabourCardExpiryDate),
            IloeIssueDate        = ParseDate(request.IloeIssueDate),
            IloeExpiryDate       = ParseDate(request.IloeExpiryDate),
            InsuranceIssueDate   = ParseDate(request.InsuranceIssueDate),
            InsuranceExpiryDate  = ParseDate(request.InsuranceExpiryDate),

            // Document URLs from Cloudinary
            EmiratesIdDocument = request.EmiratesIdDocumentUrl ?? "",
            PassportDocument   = request.PassportDocumentUrl   ?? "",
            LabourCardDocument = request.LabourCardDocumentUrl ?? "",
            IloeDocument       = request.IloeDocumentUrl       ?? "",
            InsuranceDocument  = request.InsuranceDocumentUrl  ?? "",
        };

        var id = await _repo.CreateAsync(staff);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<StaffResponse>.Ok(ToResponse(created!), "Staff member created successfully.");
    }

    public async Task<ApiResponse<StaffResponse>> UpdateAsync(int id, UpdateStaffRequest request)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<StaffResponse>.Fail("Staff member not found.");

        var uname2 = request.Username?.Trim().ToLower() ?? "";
        if (!string.IsNullOrWhiteSpace(uname2) && await _repo.UsernameExistsAsync(uname2, id))
            return ApiResponse<StaffResponse>.Fail("Username already taken by another staff member.");

        existing.Name        = request.Name?.Trim() ?? existing.Name;
        existing.Designation = request.Designation?.Trim() ?? existing.Designation;
        existing.Contact     = request.Contact?.Trim() ?? existing.Contact;
        existing.Email       = request.Email?.Trim() ?? existing.Email;
        existing.Address     = request.Address?.Trim() ?? existing.Address;
        existing.Username    = uname2;
        existing.LoginAccess = request.LoginAccess ?? existing.LoginAccess;
        existing.Status      = request.Status ?? existing.Status;
        existing.Remarks     = request.Remarks?.Trim() ?? existing.Remarks;
        existing.EmiratesId  = request.EmiratesId?.Trim() ?? existing.EmiratesId;
        existing.PassportNo  = request.PassportNo?.Trim() ?? existing.PassportNo;
        existing.Nationality = request.Nationality?.Trim() ?? existing.Nationality;
        existing.JobTitle    = request.JobTitle?.Trim() ?? existing.JobTitle;
        existing.MoveInDate  = ParseDate(request.MoveInDate);
        existing.VisaExpiry  = ParseDate(request.VisaExpiry);

        // Document dates
        existing.EmiratesIdIssueDate  = ParseDate(request.EmiratesIdIssueDate);
        existing.EmiratesIdExpiryDate = ParseDate(request.EmiratesIdExpiryDate);
        existing.PassportIssueDate    = ParseDate(request.PassportIssueDate);
        existing.PassportExpiryDate   = ParseDate(request.PassportExpiryDate);
        existing.LabourCardIssueDate  = ParseDate(request.LabourCardIssueDate);
        existing.LabourCardExpiryDate = ParseDate(request.LabourCardExpiryDate);
        existing.IloeIssueDate        = ParseDate(request.IloeIssueDate);
        existing.IloeExpiryDate       = ParseDate(request.IloeExpiryDate);
        existing.InsuranceIssueDate   = ParseDate(request.InsuranceIssueDate);
        existing.InsuranceExpiryDate  = ParseDate(request.InsuranceExpiryDate);

        // Document URLs — only overwrite if new file was uploaded
        if (request.EmiratesIdDocumentUrl != null) existing.EmiratesIdDocument = request.EmiratesIdDocumentUrl;
        if (request.PassportDocumentUrl   != null) existing.PassportDocument   = request.PassportDocumentUrl;
        if (request.LabourCardDocumentUrl != null) existing.LabourCardDocument = request.LabourCardDocumentUrl;
        if (request.IloeDocumentUrl       != null) existing.IloeDocument       = request.IloeDocumentUrl;
        if (request.InsuranceDocumentUrl  != null) existing.InsuranceDocument  = request.InsuranceDocumentUrl;

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

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static DateTime? ParseDate(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : DateTime.Parse(value);

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

        EmiratesIdIssueDate  = s.EmiratesIdIssueDate?.ToString("yyyy-MM-dd"),
        EmiratesIdExpiryDate = s.EmiratesIdExpiryDate?.ToString("yyyy-MM-dd"),
        PassportIssueDate    = s.PassportIssueDate?.ToString("yyyy-MM-dd"),
        PassportExpiryDate   = s.PassportExpiryDate?.ToString("yyyy-MM-dd"),
        LabourCardIssueDate  = s.LabourCardIssueDate?.ToString("yyyy-MM-dd"),
        LabourCardExpiryDate = s.LabourCardExpiryDate?.ToString("yyyy-MM-dd"),
        IloeIssueDate        = s.IloeIssueDate?.ToString("yyyy-MM-dd"),
        IloeExpiryDate       = s.IloeExpiryDate?.ToString("yyyy-MM-dd"),
        InsuranceIssueDate   = s.InsuranceIssueDate?.ToString("yyyy-MM-dd"),
        InsuranceExpiryDate  = s.InsuranceExpiryDate?.ToString("yyyy-MM-dd"),

        EmiratesIdDocument = string.IsNullOrEmpty(s.EmiratesIdDocument) ? null : s.EmiratesIdDocument,
        PassportDocument   = string.IsNullOrEmpty(s.PassportDocument)   ? null : s.PassportDocument,
        LabourCardDocument = string.IsNullOrEmpty(s.LabourCardDocument) ? null : s.LabourCardDocument,
        IloeDocument       = string.IsNullOrEmpty(s.IloeDocument)       ? null : s.IloeDocument,
        InsuranceDocument  = string.IsNullOrEmpty(s.InsuranceDocument)  ? null : s.InsuranceDocument,

        CreatedAt   = s.CreatedAt,
        UpdatedAt   = s.UpdatedAt,
    };
}
