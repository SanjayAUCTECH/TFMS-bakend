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
}
