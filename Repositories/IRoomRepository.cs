using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IRoomRepository
{
    Task<(IEnumerable<Room> Data, int TotalRecords)> GetAllAsync(RoomListRequest request);
    Task<IEnumerable<Room>> GetVacantRoomsByCampAsync(int campId);
    Task<Room?>  GetByIdAsync(int id);
    Task<int>    CreateAsync(Room room);
    Task<bool>   UpdateAsync(Room room);
    Task<bool>   DeleteAsync(int id);
    Task<bool>   SetOccupiedAsync(int roomId, bool occupied);
    Task<object> GetStatsAsync();
}
