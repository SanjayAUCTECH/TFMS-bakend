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

    public async Task<ApiResponse<StaffResponse>> CreateAsync(CreateStaffRequest request, int? userId = null)
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

            // 5 New Fields
            LabourCardNo    = request.LabourCardNo?.Trim() ?? "",
            DateOfBirth     = ParseDate(request.DateOfBirth),
            FitnessExpireDM = ParseDate(request.FitnessExpireDM),
            IloeNo          = request.IloeNo?.Trim() ?? "",
            InsuranceNo     = request.InsuranceNo?.Trim() ?? "",

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

            // Document URLs — file aaye toh Cloudinary URL, nahi aaye toh null
            EmiratesIdDocument = request.EmiratesIdDocumentUrl ?? null,
            PassportDocument   = request.PassportDocumentUrl   ?? null,
            LabourCardDocument = request.LabourCardDocumentUrl ?? null,
            IloeDocument       = request.IloeDocumentUrl       ?? null,
            InsuranceDocument  = request.InsuranceDocumentUrl  ?? null,
            AddedBy            = userId,
            CompanyId          = request.CompanyId,
        };

        var id = await _repo.CreateAsync(staff);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<StaffResponse>.Ok(ToResponse(created!), "Staff member created successfully.");
    }

    public async Task<ApiResponse<StaffResponse>> UpdateAsync(int id, UpdateStaffRequest request, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<StaffResponse>.Fail("Staff member not found.");

        var uname2 = request.Username?.Trim().ToLower();
        if (!string.IsNullOrWhiteSpace(uname2) && await _repo.UsernameExistsAsync(uname2, id))
            return ApiResponse<StaffResponse>.Fail("Username already taken by another staff member.");

        // Jo value aayi woh save karo, jo nahi aayi (null/empty) woh NULL save karo
        existing.Name        = request.Name?.Trim() ?? "";
        existing.Designation = request.Designation?.Trim();
        existing.Contact     = request.Contact?.Trim();
        existing.Email       = request.Email?.Trim();
        existing.Address     = request.Address?.Trim();
        existing.Username    = uname2 ?? existing.Username;
        existing.LoginAccess = request.LoginAccess ?? "enabled";
        existing.Status      = request.Status ?? "Active";
        existing.Remarks     = request.Remarks?.Trim();
        existing.EmiratesId  = request.EmiratesId?.Trim();
        existing.PassportNo  = request.PassportNo?.Trim();
        existing.Nationality = request.Nationality?.Trim();
        existing.JobTitle    = request.JobTitle?.Trim();
        existing.MoveInDate  = ParseDate(request.MoveInDate);
        existing.VisaExpiry  = ParseDate(request.VisaExpiry);

        // 5 New Fields
        existing.LabourCardNo    = request.LabourCardNo?.Trim();
        existing.DateOfBirth     = ParseDate(request.DateOfBirth);
        existing.FitnessExpireDM = ParseDate(request.FitnessExpireDM);
        existing.IloeNo          = request.IloeNo?.Trim();
        existing.InsuranceNo     = request.InsuranceNo?.Trim();

        // Document dates — value aayi toh save, nahi aayi toh null
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

        // Document URLs — controller ne upload kiya toh URL, nahi kiya toh null
        existing.EmiratesIdDocument = request.EmiratesIdDocumentUrl;
        existing.PassportDocument   = request.PassportDocumentUrl;
        existing.LabourCardDocument = request.LabourCardDocumentUrl;
        existing.IloeDocument       = request.IloeDocumentUrl;
        existing.InsuranceDocument  = request.InsuranceDocumentUrl;

        // CompanyId — jo value aayi woh save karo
        existing.CompanyId = request.CompanyId;

        // Password — sirf tab update karo jab explicitly bheja gaya ho
        if (!string.IsNullOrWhiteSpace(request.Password))
            existing.Password = request.Password;

        existing.UpdatedBy = userId;
        await _repo.UpdateAsync(existing);
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<StaffResponse>.Ok(ToResponse(updated!), "Staff member updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        if (!await _repo.ExistsAsync(id))
            return ApiResponse<bool>.Fail("Staff member not found.");
        return await _repo.DeleteAsync(id, userId)
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

        LabourCardNo    = string.IsNullOrEmpty(s.LabourCardNo)  ? null : s.LabourCardNo,
        DateOfBirth     = s.DateOfBirth?.ToString("yyyy-MM-dd"),
        FitnessExpireDM = s.FitnessExpireDM?.ToString("yyyy-MM-dd"),
        IloeNo          = string.IsNullOrEmpty(s.IloeNo)        ? null : s.IloeNo,
        InsuranceNo     = string.IsNullOrEmpty(s.InsuranceNo)   ? null : s.InsuranceNo,

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

        CompanyId   = s.CompanyId,
        CompanyName = string.IsNullOrEmpty(s.CompanyName) ? null : s.CompanyName,

        CreatedAt   = s.CreatedAt,
        UpdatedAt   = s.UpdatedAt,
    };
}
