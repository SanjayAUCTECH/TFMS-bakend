using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IWaiverRepository
{
    Task<(IEnumerable<Waiver> Data, int TotalRecords)> GetAllAsync(WaiverListRequest request);
    Task<Waiver?> GetByIdAsync(int id);
    Task<int>  CreateAsync(Waiver waiver);
    Task<bool> DeleteAsync(int id);
}
