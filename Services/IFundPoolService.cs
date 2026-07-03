using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IFundPoolService
{
    Task<ApiResponse<IEnumerable<FundPoolResponse>>> GetAllAsync(FundPoolListRequest request);
    Task<ApiResponse<IEnumerable<FundPoolResponse>>> GetAllActiveAsync();
    Task<ApiResponse<FundPoolResponse>> GetByIdAsync(int id);
    Task<ApiResponse<FundPoolResponse>> CreateAsync(CreateFundPoolRequest request);
    Task<ApiResponse<FundPoolResponse>> UpdateAsync(int id, UpdateFundPoolRequest request);
    Task<ApiResponse<bool>>             DeleteAsync(int id);
}
