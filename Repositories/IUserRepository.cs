using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IUserRepository
{
    Task<(IEnumerable<AppUser> Data, int TotalRecords)> GetAllAsync(UserListRequest request);
    Task<AppUser?> GetByIdAsync(int id);
    Task<AppUser?> GetByUsernameAsync(string username);
    Task<int>      CreateAsync(AppUser user);
    Task<bool>     UpdateAsync(AppUser user);
    Task<bool>     UpdatePasswordAsync(int id, string password);
    Task<bool>     UpdateMenuAccessAsync(int id, string menuAccess);
    Task<bool>     UpdateLoginAccessAsync(int id, string loginAccess);
    Task<bool>     DeleteAsync(int id);
    Task<bool>     ExistsAsync(int id);
    Task<bool>     UsernameExistsAsync(string username, int? excludeId = null);
    Task<UserStatsResponse> GetStatsAsync();
}
