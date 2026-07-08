using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IDashboardRepository
{
    Task<DashboardStatsResponse> GetStatsAsync(int? campId = null, int? tenantId = null, string? month = null);
    Task<AppUser?> GetUserByUsernameAsync(string username);
    Task UpdateLastLoginAsync(int userId);
}
