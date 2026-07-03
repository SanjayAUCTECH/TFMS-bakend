using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IDashboardService
{
    Task<ApiResponse<DashboardStatsResponse>> GetStatsAsync();
}
