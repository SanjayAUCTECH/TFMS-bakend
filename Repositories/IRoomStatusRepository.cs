using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IRoomStatusRepository
{
    Task<IEnumerable<RoomStatus>> GetAllAsync();
    Task<RoomStatus?> GetByIdAsync(int id);
    Task<int>  CreateAsync(RoomStatus rs);
    Task<bool> UpdateAsync(RoomStatus rs);
    Task<bool> DeleteAsync(int id);
}
