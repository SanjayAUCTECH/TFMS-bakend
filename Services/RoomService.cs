using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class RoomService : IRoomService
{
    private readonly IRoomRepository _repo;
    public RoomService(IRoomRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<RoomResponse>>> GetAllAsync(RoomListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var cards = await _repo.GetStatsAsync();
        return ApiResponse<IEnumerable<RoomResponse>>.Ok(
            data.Select(ToResponse), "Rooms retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize), cards);
    }

    public async Task<ApiResponse<IEnumerable<RoomResponse>>> GetVacantByCampAsync(int campId)
        => ApiResponse<IEnumerable<RoomResponse>>.Ok((await _repo.GetVacantRoomsByCampAsync(campId)).Select(ToResponse));

    public async Task<ApiResponse<RoomResponse>> GetByIdAsync(int id)
    {
        var r = await _repo.GetByIdAsync(id);
        return r == null ? ApiResponse<RoomResponse>.Fail("Not found.") : ApiResponse<RoomResponse>.Ok(ToResponse(r));
    }

    public async Task<ApiResponse<RoomResponse>> CreateAsync(CreateRoomRequest request)
    {
        var id = await _repo.CreateAsync(new Room
        {
            RoomNo = request.RoomNo.Trim(), CampId = request.CampId ?? 0, FloorId = request.FloorId ?? 0,
            MonthlyPrice = request.MonthlyPrice, Status = request.Status, OtherDetails = request.OtherDetails.Trim()
        });
        return ApiResponse<RoomResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Room created.");
    }

    public async Task<ApiResponse<RoomResponse>> UpdateAsync(int id, UpdateRoomRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<RoomResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new Room
        {
            Id = id, RoomNo = request.RoomNo.Trim(), CampId = request.CampId ?? 0, FloorId = request.FloorId ?? 0,
            MonthlyPrice = request.MonthlyPrice, Status = request.Status, OtherDetails = request.OtherDetails.Trim()
        });
        return ApiResponse<RoomResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Room updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static RoomResponse ToResponse(Room r) => new()
    {
        Id = r.Id, RoomNo = r.RoomNo, CampId = r.CampId, CampName = r.CampName,
        FloorId = r.FloorId, FloorName = r.FloorName, Occupied = r.Occupied,
        MonthlyPrice = r.MonthlyPrice, Status = r.Status, OtherDetails = r.OtherDetails,
        CreatedAt = r.CreatedAt, UpdatedAt = r.UpdatedAt
    };
}
