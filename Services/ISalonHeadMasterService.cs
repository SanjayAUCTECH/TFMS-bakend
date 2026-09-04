using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonHeadMasterService
{
    Task<ApiResponse<IEnumerable<SalonHeadMasterResponse>>> GetAllAsync(SalonHeadMasterListRequest request);
    Task<ApiResponse<IEnumerable<SalonHeadMasterResponse>>> GetAllActiveAsync(string? headType = null);
    Task<ApiResponse<SalonHeadMasterResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<SalonHeadMasterResponse>>              CreateAsync(CreateSalonHeadMasterRequest request, int? userId = null);
    Task<ApiResponse<SalonHeadMasterResponse>>              UpdateAsync(int id, UpdateSalonHeadMasterRequest request, int? userId = null);
    Task<ApiResponse<bool>>                                 DeleteAsync(int id, int? userId = null);
}
