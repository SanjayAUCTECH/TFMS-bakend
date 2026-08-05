using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ICampbossRepository
{
    Task<(IEnumerable<Campboss> Data, int TotalRecords)> GetAllAsync(CampbossListRequest request);
    Task<Campboss?> GetByIdAsync(int id);
    Task<int>  CreateAsync(Campboss campboss);
    Task<bool> UpdateAsync(Campboss campboss);
    Task<bool> DeleteAsync(int id, int? deletedBy = null);
    Task<bool> UsernameExistsAsync(string username, int? excludeId = null);
}
