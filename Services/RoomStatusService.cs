using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class RoomStatusService : IRoomStatusService
{
    private readonly IRoomStatusRepository _repo;
    public RoomStatusService(IRoomStatusRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<RoomStatusResponse>>> GetAllAsync()
    {
        var data = await _repo.GetAllAsync();
        return ApiResponse<IEnumerable<RoomStatusResponse>>.Ok(data.Select(r => new RoomStatusResponse { Id = r.Id, Name = r.Name }));
    }

    public async Task<ApiResponse<RoomStatusResponse>> GetByIdAsync(int id)
    {
        var rs = await _repo.GetByIdAsync(id);
        return rs == null ? ApiResponse<RoomStatusResponse>.Fail("Not found.") : ApiResponse<RoomStatusResponse>.Ok(new RoomStatusResponse { Id = rs.Id, Name = rs.Name });
    }

    public async Task<ApiResponse<RoomStatusResponse>> CreateAsync(CreateRoomStatusRequest request)
    {
        var id = await _repo.CreateAsync(new RoomStatus { Name = request.Name.Trim() });
        var rs = await _repo.GetByIdAsync(id);
        return ApiResponse<RoomStatusResponse>.Ok(new RoomStatusResponse { Id = rs!.Id, Name = rs.Name }, "Room Status created.");
    }

    public async Task<ApiResponse<RoomStatusResponse>> UpdateAsync(int id, UpdateRoomStatusRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<RoomStatusResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new RoomStatus { Id = id, Name = request.Name.Trim() });
        var rs = await _repo.GetByIdAsync(id);
        return ApiResponse<RoomStatusResponse>.Ok(new RoomStatusResponse { Id = rs!.Id, Name = rs.Name }, "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }
}
