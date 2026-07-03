using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IRoomService
{
    Task<ApiResponse<IEnumerable<RoomResponse>>> GetAllAsync(RoomListRequest request);
    Task<ApiResponse<IEnumerable<RoomResponse>>> GetVacantByCampAsync(int campId);
    Task<ApiResponse<RoomResponse>> GetByIdAsync(int id);
    Task<ApiResponse<RoomResponse>> CreateAsync(CreateRoomRequest request);
    Task<ApiResponse<RoomResponse>> UpdateAsync(int id, UpdateRoomRequest request);
    Task<ApiResponse<bool>>         DeleteAsync(int id);
}
