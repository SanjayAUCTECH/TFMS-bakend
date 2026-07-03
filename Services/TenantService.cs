using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class TenantService : ITenantService
{
    private readonly ITenantRepository _repo;
    public TenantService(ITenantRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<TenantResponse>>> GetAllAsync(TenantListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<TenantResponse>>.Ok(
            data.Select(ToResponse), "Tenants retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<TenantResponse>> GetByIdAsync(int id)
    {
        var t = await _repo.GetByIdAsync(id);
        return t == null ? ApiResponse<TenantResponse>.Fail("Tenant not found.") : ApiResponse<TenantResponse>.Ok(ToResponse(t));
    }

    public async Task<ApiResponse<TenantResponse>> CreateAsync(CreateTenantRequest request)
    {
        var newId = await _repo.CreateAsync(FromRequest(request));
        return ApiResponse<TenantResponse>.Ok(ToResponse((await _repo.GetByIdAsync(newId))!), "Tenant created.");
    }

    public async Task<ApiResponse<TenantResponse>> UpdateAsync(int id, UpdateTenantRequest request)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<TenantResponse>.Fail("Tenant not found.");
        await _repo.UpdateAsync(FromRequest(request, id));
        return ApiResponse<TenantResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Tenant updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("Tenant not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Tenant deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static Tenant FromRequest(CreateTenantRequest r, int id = 0) => new()
    {
        Id = id, Type = r.Type, Name = r.Name.Trim(), Passport = r.Passport.Trim(),
        Nationality = r.Nationality.Trim(), EmiratesId = r.EmiratesId.Trim(),
        Contact = r.Contact.Trim(), Whatsapp = r.Whatsapp.Trim(), Email = r.Email.Trim(),
        Address = r.Address.Trim(), Status = r.Status,
        Company = r.Company.Trim(), TradeLicense = r.TradeLicense.Trim(),
        LicensingAuthority = r.LicensingAuthority.Trim(),
        NumberOfCoOccupants = r.NumberOfCoOccupants.Trim(),
        PlotNo = r.PlotNo.Trim(), MakaniNo = r.MakaniNo.Trim(),
        PropertyArea = r.PropertyArea.Trim(), PremisesNo = r.PremisesNo.Trim(),
        LessorName = r.LessorName.Trim(), LessorEid = r.LessorEid.Trim(),
        LessorLicense = r.LessorLicense.Trim(), LessorLicAuthority = r.LessorLicAuthority.Trim(),
        LessorEmail = r.LessorEmail.Trim(), LessorPhone = r.LessorPhone.Trim(),
    };

    private static TenantResponse ToResponse(Tenant t) => new()
    {
        Id = t.Id, Type = t.Type, Name = t.Name, Passport = t.Passport,
        Nationality = t.Nationality, EmiratesId = t.EmiratesId, Contact = t.Contact,
        Whatsapp = t.Whatsapp, Email = t.Email, Address = t.Address, Status = t.Status,
        Company = t.Company, TradeLicense = t.TradeLicense, LicensingAuthority = t.LicensingAuthority,
        NumberOfCoOccupants = t.NumberOfCoOccupants, PlotNo = t.PlotNo, MakaniNo = t.MakaniNo,
        PropertyArea = t.PropertyArea, PremisesNo = t.PremisesNo, LessorName = t.LessorName,
        LessorEid = t.LessorEid, LessorLicense = t.LessorLicense, LessorLicAuthority = t.LessorLicAuthority,
        LessorEmail = t.LessorEmail, LessorPhone = t.LessorPhone,
        CreatedAt = t.CreatedAt, UpdatedAt = t.UpdatedAt,
    };
}
