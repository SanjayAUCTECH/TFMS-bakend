using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IDesignationService
{
    Task<ApiResponse<IEnumerable<DesignationResponse>>> GetAllAsync(DesignationListRequest request);
    Task<ApiResponse<IEnumerable<DesignationResponse>>> GetAllActiveAsync();
    Task<ApiResponse<DesignationResponse>> GetByIdAsync(int id);
    Task<ApiResponse<DesignationResponse>> CreateAsync(CreateDesignationRequest request);
    Task<ApiResponse<DesignationResponse>> UpdateAsync(int id, UpdateDesignationRequest request);
    Task<ApiResponse<bool>>                DeleteAsync(int id);
}
