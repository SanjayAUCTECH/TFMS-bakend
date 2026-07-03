using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ITenantRepository
{
    Task<(IEnumerable<Tenant> Data, int TotalRecords)> GetAllAsync(TenantListRequest request);
    Task<Tenant?> GetByIdAsync(int id);
    Task<int>  CreateAsync(Tenant tenant);
    Task<bool> UpdateAsync(Tenant tenant);
    Task<bool> DeleteAsync(int id);
    Task<bool> ExistsAsync(int id);
}
