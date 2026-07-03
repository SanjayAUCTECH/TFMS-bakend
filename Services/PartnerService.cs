using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class PartnerService : IPartnerService
{
    private readonly IPartnerRepository _repo;
    public PartnerService(IPartnerRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<PartnerResponse>>> GetAllAsync(PartnerListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<PartnerResponse>>.Ok(
            data.Select(ToResponse), "Partners retrieved successfully",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<PartnerResponse>> GetByIdAsync(int id)
    {
        var partner = await _repo.GetByIdAsync(id);
        if (partner == null) return ApiResponse<PartnerResponse>.Fail("Partner not found.");
        return ApiResponse<PartnerResponse>.Ok(ToResponse(partner));
    }

    public async Task<ApiResponse<PartnerResponse>> CreateAsync(CreatePartnerRequest request)
    {
        var partner = new Partner
        {
            Name = request.Name.Trim(), Contact = request.Contact.Trim(),
            Mobile = request.Mobile.Trim(), Email = request.Email.Trim(), Status = request.Status,
        };
        var id = await _repo.CreateAsync(partner);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<PartnerResponse>.Ok(ToResponse(created!), "Partner created successfully.");
    }

    public async Task<ApiResponse<PartnerResponse>> UpdateAsync(int id, UpdatePartnerRequest request)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<PartnerResponse>.Fail("Partner not found.");
        await _repo.UpdateAsync(new Partner
        {
            Id = id, Name = request.Name.Trim(), Contact = request.Contact.Trim(),
            Mobile = request.Mobile.Trim(), Email = request.Email.Trim(), Status = request.Status,
        });
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<PartnerResponse>.Ok(ToResponse(updated!), "Partner updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("Partner not found.");
        var result = await _repo.DeleteAsync(id);
        return result ? ApiResponse<bool>.Ok(true, "Partner deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static PartnerResponse ToResponse(Partner p) => new()
    {
        Id = p.Id, Code = p.Code, Name = p.Name, Contact = p.Contact,
        Mobile = p.Mobile, Email = p.Email, Status = p.Status,
        CreatedAt = p.CreatedAt, UpdatedAt = p.UpdatedAt,
    };
}
