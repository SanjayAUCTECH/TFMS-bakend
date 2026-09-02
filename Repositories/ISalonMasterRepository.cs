using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ISalonMasterRepository
{
    Task<(IEnumerable<SalonMaster> Data, int TotalRecords)> GetAllAsync(SalonMasterListRequest request);
    Task<SalonMaster?> GetByIdAsync(int id);
    Task<int>  CreateAsync(SalonMaster salon);
    Task<bool> UpdateAsync(SalonMaster salon);
    Task<bool> DeleteAsync(int id, int? deletedBy = null);
}
