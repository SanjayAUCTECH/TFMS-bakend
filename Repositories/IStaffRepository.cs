using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IStaffRepository
{
    Task<(IEnumerable<Staff> Data, int TotalRecords)> GetAllAsync(StaffListRequest request);
    Task<Staff?> GetByIdAsync(int id);
    Task<Staff?> GetByUsernameAsync(string username);
    Task<int>    CreateAsync(Staff staff);
    Task<bool>   UpdateAsync(Staff staff);
    Task<bool>   DeleteAsync(int id);
    Task<bool>   ExistsAsync(int id);
    Task<bool>   UsernameExistsAsync(string username, int? excludeId = null);
}
