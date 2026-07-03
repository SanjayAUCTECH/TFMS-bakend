using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IRoomStatusService
{
    Task<ApiResponse<IEnumerable<RoomStatusResponse>>> GetAllAsync();
    Task<ApiResponse<RoomStatusResponse>> GetByIdAsync(int id);
    Task<ApiResponse<RoomStatusResponse>> CreateAsync(CreateRoomStatusRequest request);
    Task<ApiResponse<RoomStatusResponse>> UpdateAsync(int id, UpdateRoomStatusRequest request);
    Task<ApiResponse<bool>>               DeleteAsync(int id);
}
