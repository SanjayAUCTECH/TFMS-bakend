using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonStaffAssignService
{
    Task<ApiResponse<IEnumerable<SalonStaffAssignResponse>>> GetAllAsync(SalonStaffAssignListRequest request);
    Task<ApiResponse<SalonStaffAssignResponse>>              GetByIdAsync(int assignId);
    Task<ApiResponse<SalonStaffAssignResponse>>              CreateAsync(CreateSalonStaffAssignRequest request, int? userId = null);
    Task<ApiResponse<SalonStaffAssignResponse>>              UpdateAsync(int assignId, UpdateSalonStaffAssignRequest request, int? userId = null);
    Task<ApiResponse<bool>>                                  DeleteAsync(int assignId, int? userId = null);
}
