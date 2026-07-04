using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ICampRepository
{
    Task<(IEnumerable<Camp> Data, int TotalRecords)> GetAllAsync(CampListRequest request);
    Task<IEnumerable<Camp>> GetAllActiveAsync();
    Task<Camp?>  GetByIdAsync(int id);
    Task<int>    CreateAsync(Camp camp);
    Task<bool>   UpdateAsync(Camp camp);
    Task<bool>   DeleteAsync(int id);
    Task<object> GetStatsAsync();
}
