using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IStaffService
{
    Task<ApiResponse<IEnumerable<StaffResponse>>> GetAllAsync(StaffListRequest request);
    Task<ApiResponse<StaffResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<StaffResponse>>              CreateAsync(CreateStaffRequest request);
    Task<ApiResponse<StaffResponse>>              UpdateAsync(int id, UpdateStaffRequest request);
    Task<ApiResponse<bool>>                       DeleteAsync(int id);
}
