using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ISalonHeadMasterRepository
{
    Task<(IEnumerable<SalonHeadMaster> Data, int TotalRecords)> GetAllAsync(SalonHeadMasterListRequest request);
    Task<IEnumerable<SalonHeadMaster>> GetAllActiveAsync(string? headType = null);
    Task<SalonHeadMaster?> GetByIdAsync(int id);
    Task<int>  CreateAsync(SalonHeadMaster head);
    Task<bool> UpdateAsync(SalonHeadMaster head);
    Task<bool> DeleteAsync(int id, int? deletedBy = null);
}
