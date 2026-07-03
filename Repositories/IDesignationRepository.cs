using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IDesignationRepository
{
    Task<(IEnumerable<Designation> Data, int TotalRecords)> GetAllAsync(DesignationListRequest request);
    Task<IEnumerable<Designation>> GetAllActiveAsync();
    Task<Designation?> GetByIdAsync(int id);
    Task<int>  CreateAsync(Designation d);
    Task<bool> UpdateAsync(Designation d);
    Task<bool> DeleteAsync(int id);
}
