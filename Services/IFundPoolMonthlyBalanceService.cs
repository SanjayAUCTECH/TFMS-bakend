using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IFundPoolMonthlyBalanceService
{
    Task<ApiResponse<IEnumerable<FundPoolMonthlyBalanceResponse>>> SaveMonthlyBalanceAsync(SaveFundPoolMonthlyBalanceRequest request, int? userId);
    Task<ApiResponse<object>> GetMonthlyBalanceAsync(GetFundPoolMonthlyBalanceRequest request);
    Task<ApiResponse<IEnumerable<FundPoolMonthlyBalanceSummaryResponse>>> GetAllMonthlyBalancesAsync(FundPoolMonthlyBalanceListRequest request);
    Task<ApiResponse<bool>> DeleteMonthlyBalanceAsync(DeleteFundPoolMonthlyBalanceRequest request, int? userId);
}
