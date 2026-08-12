using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IPartnerPayoutService
{
    Task<ApiResponse<PartnerPayoutDataResponse>>            GetPayoutDataAsync(int month, int year);
    Task<ApiResponse<SavePartnerMonthlyCampPayoutResponse>> SaveMonthlyCampPayoutAsync(SavePartnerMonthlyCampPayoutRequest request, int? userId);
    Task<ApiResponse<IEnumerable<PartnerMonthlyCampPayoutResponse>>> GetMonthlyCampPayoutAsync(GetPartnerMonthlyCampPayoutRequest request);
    Task<ApiResponse<PartnerPayoutByMonthResponse>> GetPartnerPayoutByMonthAsync(int month, int year);
    Task<ApiResponse<SavePartnerMonthlyPayoutResponse>> SaveMonthlyPayoutAsync(SavePartnerMonthlyPayoutRequest request, int? userId);
    Task<ApiResponse<DeletePartnerMonthlyPayoutResponse>> DeleteMonthlyPayoutAsync(DeletePartnerMonthlyPayoutRequest request, int? userId);
    Task<ApiResponse<GetPartnerMonthlyPayoutListResponse>> GetMonthlyPayoutListAsync(int month, int year, int? partnerId);
    Task<ApiResponse<PartnerReleasePayoutResponse>> SaveReleasePayoutAsync(CreatePartnerReleasePayoutRequest request, int? userId);
}
