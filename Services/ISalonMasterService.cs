using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonMasterService
{
    Task<ApiResponse<IEnumerable<SalonMasterResponse>>> GetAllAsync(SalonMasterListRequest request);
    Task<ApiResponse<SalonMasterResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<SalonMasterResponse>>              CreateAsync(CreateSalonMasterRequest request, int? userId = null);
    Task<ApiResponse<SalonMasterResponse>>              UpdateAsync(int id, UpdateSalonMasterRequest request, int? userId = null);
    Task<ApiResponse<bool>>                             DeleteAsync(int id, int? userId = null);
}
