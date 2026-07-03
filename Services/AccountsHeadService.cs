using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class AccountsHeadService : IAccountsHeadService
{
    private static readonly string[] ValidTypes = { "Asset", "Liability", "Income", "Expense", "Capital" };
    private readonly IAccountsHeadRepository _repo;
    public AccountsHeadService(IAccountsHeadRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<AccountsHeadResponse>>> GetAllAsync(AccountsHeadListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<AccountsHeadResponse>>.Ok(
            data.Select(ToResponse), "Accounts Heads retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<AccountsHeadResponse>>> GetAllActiveAsync()
        => ApiResponse<IEnumerable<AccountsHeadResponse>>.Ok((await _repo.GetAllActiveAsync()).Select(ToResponse));

    public async Task<ApiResponse<AccountsHeadResponse>> GetByIdAsync(int id)
    {
        var a = await _repo.GetByIdAsync(id);
        return a == null ? ApiResponse<AccountsHeadResponse>.Fail("Not found.") : ApiResponse<AccountsHeadResponse>.Ok(ToResponse(a));
    }

    public async Task<ApiResponse<AccountsHeadResponse>> CreateAsync(CreateAccountsHeadRequest request)
    {
        if (!ValidTypes.Contains(request.Type)) return ApiResponse<AccountsHeadResponse>.Fail("Invalid account type.");
        var id = await _repo.CreateAsync(new AccountsHead { Name = request.Name.Trim(), Type = request.Type, Status = request.Status });
        return ApiResponse<AccountsHeadResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Accounts Head created.");
    }

    public async Task<ApiResponse<AccountsHeadResponse>> UpdateAsync(int id, UpdateAccountsHeadRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<AccountsHeadResponse>.Fail("Not found.");
        if (!ValidTypes.Contains(request.Type)) return ApiResponse<AccountsHeadResponse>.Fail("Invalid account type.");
        await _repo.UpdateAsync(new AccountsHead { Id = id, Name = request.Name.Trim(), Type = request.Type, Status = request.Status });
        return ApiResponse<AccountsHeadResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static AccountsHeadResponse ToResponse(AccountsHead a) => new()
    {
        Id = a.Id, Code = a.Code, Name = a.Name, Type = a.Type,
        Status = a.Status, CreatedAt = a.CreatedAt, UpdatedAt = a.UpdatedAt
    };
}
