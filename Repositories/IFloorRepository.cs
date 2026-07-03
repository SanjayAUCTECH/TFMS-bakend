using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IFloorRepository
{
    Task<(IEnumerable<Floor> Data, int TotalRecords)> GetAllAsync(FloorListRequest request);
    Task<IEnumerable<Floor>> GetAllActiveAsync();
    Task<Floor?>  GetByIdAsync(int id);
    Task<int>     CreateAsync(Floor floor);
    Task<bool>    UpdateAsync(Floor floor);
    Task<bool>    DeleteAsync(int id);
}
