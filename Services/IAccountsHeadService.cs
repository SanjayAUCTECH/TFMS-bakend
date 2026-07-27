using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IAccountsHeadService
{
    Task<ApiResponse<IEnumerable<AccountsHeadResponse>>> GetAllAsync(AccountsHeadListRequest request);
    Task<ApiResponse<IEnumerable<AccountsHeadResponse>>> GetAllActiveAsync();
    Task<ApiResponse<AccountsHeadResponse>> GetByIdAsync(int id);
    Task<ApiResponse<AccountsHeadResponse>> CreateAsync(CreateAccountsHeadRequest request, int? userId = null);
    Task<ApiResponse<AccountsHeadResponse>> UpdateAsync(int id, UpdateAccountsHeadRequest request, int? userId = null);
    Task<ApiResponse<bool>>                 DeleteAsync(int id, int? userId = null);
}
