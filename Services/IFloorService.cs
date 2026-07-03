using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IFloorService
{
    Task<ApiResponse<IEnumerable<FloorResponse>>> GetAllAsync(FloorListRequest request);
    Task<ApiResponse<IEnumerable<FloorResponse>>> GetAllActiveAsync();
    Task<ApiResponse<FloorResponse>> GetByIdAsync(int id);
    Task<ApiResponse<FloorResponse>> CreateAsync(CreateFloorRequest request);
    Task<ApiResponse<FloorResponse>> UpdateAsync(int id, UpdateFloorRequest request);
    Task<ApiResponse<bool>>          DeleteAsync(int id);
}
