using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IOwnerRepository
{
    Task<(IEnumerable<Owner> Data, int TotalRecords)> GetAllAsync(OwnerListRequest request);
    Task<Owner?>  GetByIdAsync(int id);
    Task<int>     CreateAsync(Owner owner);
    Task<bool>    UpdateAsync(Owner owner);
    Task<bool>    DeleteAsync(int id);
    Task<bool>    ExistsAsync(int id);
}
