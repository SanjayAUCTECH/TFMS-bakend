using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonFundBalanceService
{
    Task<ApiResponse<SalonFundBalanceResponse>> GetBalanceAsync(SalonFundBalanceRequest request);
}
