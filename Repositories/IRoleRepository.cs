using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IRoleRepository
{
    Task<(IEnumerable<Role> Data, int TotalRecords)> GetAllAsync(RoleListRequest request);
    Task<IEnumerable<Role>> GetAllActiveAsync();
    Task<Role?>  GetByIdAsync(int id);
    Task<int>    CreateAsync(Role role);
    Task<bool>   UpdateAsync(Role role);
    Task<bool>   DeleteAsync(int id);
    Task<object> GetStatsAsync();
}
