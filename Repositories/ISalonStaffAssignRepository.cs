using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ISalonStaffAssignRepository
{
    Task<(IEnumerable<SalonStaffAssign> Data, int TotalRecords)> GetAllAsync(SalonStaffAssignListRequest request);
    Task<SalonStaffAssign?> GetByIdAsync(int assignId);
    Task<int>  CreateAsync(SalonStaffAssign assign);
    Task<bool> UpdateAsync(SalonStaffAssign assign);
    Task<bool> DeleteAsync(int assignId, int? deletedBy = null);
}
