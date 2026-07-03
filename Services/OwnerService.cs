using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class OwnerService : IOwnerService
{
    private readonly IOwnerRepository _repo;
    public OwnerService(IOwnerRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<OwnerResponse>>> GetAllAsync(OwnerListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<OwnerResponse>>.Ok(
            data.Select(ToResponse), "Owners retrieved successfully",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<OwnerResponse>> GetByIdAsync(int id)
    {
        var o = await _repo.GetByIdAsync(id);
        return o == null ? ApiResponse<OwnerResponse>.Fail("Owner not found.") : ApiResponse<OwnerResponse>.Ok(ToResponse(o));
    }

    public async Task<ApiResponse<OwnerResponse>> CreateAsync(CreateOwnerRequest request)
    {
        var o = new Owner { Name = request.Name.Trim(), Contact = request.Contact.Trim(), Email = request.Email.Trim(), Status = request.Status };
        var id = await _repo.CreateAsync(o);
        return ApiResponse<OwnerResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Owner created.");
    }

    public async Task<ApiResponse<OwnerResponse>> UpdateAsync(int id, UpdateOwnerRequest request)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<OwnerResponse>.Fail("Owner not found.");
        await _repo.UpdateAsync(new Owner { Id = id, Name = request.Name.Trim(), Contact = request.Contact.Trim(), Email = request.Email.Trim(), Status = request.Status });
        return ApiResponse<OwnerResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Owner updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id)) return ApiResponse<bool>.Fail("Owner not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Owner deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static OwnerResponse ToResponse(Owner o) => new()
    {
        Id = o.Id, Code = o.Code, Name = o.Name, Contact = o.Contact,
        Email = o.Email, Status = o.Status, CreatedAt = o.CreatedAt, UpdatedAt = o.UpdatedAt
    };
}
