using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class OtherPersonService : IOtherPersonService
{
    private readonly IOtherPersonRepository _repo;
    public OtherPersonService(IOtherPersonRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<OtherPersonResponse>>> GetAllAsync(OtherPersonListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<OtherPersonResponse>>.Ok(
            data.Select(ToResponse), "Other Persons retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<OtherPersonResponse>> GetByIdAsync(int id)
    {
        var o = await _repo.GetByIdAsync(id);
        return o == null ? ApiResponse<OtherPersonResponse>.Fail("Not found.") : ApiResponse<OtherPersonResponse>.Ok(ToResponse(o));
    }

    public async Task<ApiResponse<OtherPersonResponse>> CreateAsync(CreateOtherPersonRequest request)
    {
        var op = new OtherPerson
        {
            Designation = request.Designation, Name = request.Name.Trim(), Mobile = request.Mobile.Trim(),
            Email = request.Email.Trim(), Address = request.Address.Trim(), City = request.City.Trim(),
            State = request.State.Trim(), Pincode = request.Pincode.Trim(), Remarks = request.Remarks.Trim(),
            Status = request.Status,
        };
        var id = await _repo.CreateAsync(op);
        return ApiResponse<OtherPersonResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Other Person created.");
    }

    public async Task<ApiResponse<OtherPersonResponse>> UpdateAsync(int id, UpdateOtherPersonRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<OtherPersonResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new OtherPerson
        {
            Id = id, Designation = request.Designation, Name = request.Name.Trim(), Mobile = request.Mobile.Trim(),
            Email = request.Email.Trim(), Address = request.Address.Trim(), City = request.City.Trim(),
            State = request.State.Trim(), Pincode = request.Pincode.Trim(), Remarks = request.Remarks.Trim(),
            Status = request.Status,
        });
        return ApiResponse<OtherPersonResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static OtherPersonResponse ToResponse(OtherPerson o) => new()
    {
        Id = o.Id, Code = o.Code, Designation = o.Designation, Name = o.Name,
        Mobile = o.Mobile, Email = o.Email, Address = o.Address, City = o.City,
        State = o.State, Pincode = o.Pincode, Remarks = o.Remarks, Status = o.Status,
        CreatedAt = o.CreatedAt, UpdatedAt = o.UpdatedAt
    };
}
