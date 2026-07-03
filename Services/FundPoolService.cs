using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class FundPoolService : IFundPoolService
{
    private readonly IFundPoolRepository _repo;
    public FundPoolService(IFundPoolRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<FundPoolResponse>>> GetAllAsync(FundPoolListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<FundPoolResponse>>.Ok(
            data.Select(ToResponse), "Fund Pools retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<FundPoolResponse>>> GetAllActiveAsync()
        => ApiResponse<IEnumerable<FundPoolResponse>>.Ok((await _repo.GetAllActiveAsync()).Select(ToResponse));

    public async Task<ApiResponse<FundPoolResponse>> GetByIdAsync(int id)
    {
        var f = await _repo.GetByIdAsync(id);
        return f == null ? ApiResponse<FundPoolResponse>.Fail("Not found.") : ApiResponse<FundPoolResponse>.Ok(ToResponse(f));
    }

    public async Task<ApiResponse<FundPoolResponse>> CreateAsync(CreateFundPoolRequest request)
    {
        var id = await _repo.CreateAsync(new FundPool { Name = request.Name.Trim(), Balance = request.Balance, Status = request.Status });
        return ApiResponse<FundPoolResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Fund Pool created.");
    }

    public async Task<ApiResponse<FundPoolResponse>> UpdateAsync(int id, UpdateFundPoolRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<FundPoolResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new FundPool { Id = id, Name = request.Name.Trim(), Balance = request.Balance, Status = request.Status });
        return ApiResponse<FundPoolResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static FundPoolResponse ToResponse(FundPool f) => new()
    {
        Id = f.Id, Code = f.Code, Name = f.Name, Status = f.Status,
        Balance = f.Balance, CreatedAt = f.CreatedAt, UpdatedAt = f.UpdatedAt
    };
}
