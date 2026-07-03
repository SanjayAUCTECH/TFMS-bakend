using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IOtherPersonRepository
{
    Task<(IEnumerable<OtherPerson> Data, int TotalRecords)> GetAllAsync(OtherPersonListRequest request);
    Task<OtherPerson?> GetByIdAsync(int id);
    Task<int>  CreateAsync(OtherPerson op);
    Task<bool> UpdateAsync(OtherPerson op);
    Task<bool> DeleteAsync(int id);
}
