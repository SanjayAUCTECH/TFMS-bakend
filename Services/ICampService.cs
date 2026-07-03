using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ICampService
{
    Task<ApiResponse<IEnumerable<CampResponse>>> GetAllAsync(CampListRequest request);
    Task<ApiResponse<IEnumerable<CampResponse>>> GetAllActiveAsync();
    Task<ApiResponse<CampResponse>> GetByIdAsync(int id);
    Task<ApiResponse<CampResponse>> CreateAsync(CreateCampRequest request);
    Task<ApiResponse<CampResponse>> UpdateAsync(int id, UpdateCampRequest request);
    Task<ApiResponse<bool>>         DeleteAsync(int id);
}
