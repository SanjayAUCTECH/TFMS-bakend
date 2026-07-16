using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class DashboardService : IDashboardService
{
    private readonly IDashboardRepository _repo;
    public DashboardService(IDashboardRepository repo) => _repo = repo;

    public async Task<ApiResponse<DashboardStatsResponse>> GetStatsAsync(int? campId = null, int? tenantId = null, string? month = null)
    {
        var stats = await _repo.GetStatsAsync(campId, tenantId, month);
        return ApiResponse<DashboardStatsResponse>.Ok(stats, "Dashboard stats retrieved.");
    }

    public async Task<ApiResponse<StaffExpiryAlertResponse>> GetStaffExpiryAlertsAsync(int daysAhead = 30)
    {
        var alerts = await _repo.GetStaffExpiryAlertsAsync(daysAhead);
        return ApiResponse<StaffExpiryAlertResponse>.Ok(alerts,
            $"Found {alerts.TotalAlerts} document alert(s): {alerts.ExpiredCount} expired, {alerts.ExpiringSoon} expiring soon.");
    }

    public async Task<ApiResponse<OwnerPaymentAlertResponse>> GetOwnerPaymentAlertsAsync(int daysAhead = 2)
    {
        var alerts = await _repo.GetOwnerPaymentAlertsAsync(daysAhead);
        return ApiResponse<OwnerPaymentAlertResponse>.Ok(alerts,
            $"Found {alerts.TotalAlerts} owner payment alert(s) due within {daysAhead} day(s).");
    }

    public async Task<ApiResponse<OwnerMonthSummaryResponse>> GetOwnerMonthSummaryAsync(string? month = null)
    {
        var summary = await _repo.GetOwnerMonthSummaryAsync(month);
        return ApiResponse<OwnerMonthSummaryResponse>.Ok(summary,
            $"Owner payment summary for {summary.Month} retrieved.");
    }
}
