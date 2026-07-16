using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IDashboardService
{
    Task<ApiResponse<DashboardStatsResponse>>   GetStatsAsync(int? campId = null, int? tenantId = null, string? month = null);
    Task<ApiResponse<StaffExpiryAlertResponse>> GetStaffExpiryAlertsAsync(int daysAhead = 30);
    Task<ApiResponse<OwnerPaymentAlertResponse>> GetOwnerPaymentAlertsAsync(int daysAhead = 2);
    Task<ApiResponse<OwnerMonthSummaryResponse>> GetOwnerMonthSummaryAsync(string? month = null);
}
