using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IAccountMasterService
{
    Task<ApiResponse<IEnumerable<AccountMasterDetailResponse>>> GetAllAsync(AccountMasterListRequest request);
    Task<ApiResponse<AccountMasterDetailResponse>> GetByIdAsync(int id);
    Task<ApiResponse<AccountMasterDetailResponse>> CreateAsync(CreateAccountMasterRequest request, int? userId = null);
    Task<ApiResponse<AccountMasterDetailResponse>> UpdateAsync(int id, UpdateAccountMasterRequest request, int? userId = null);
    Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null);
}
