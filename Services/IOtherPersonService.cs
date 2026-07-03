using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IOtherPersonService
{
    Task<ApiResponse<IEnumerable<OtherPersonResponse>>> GetAllAsync(OtherPersonListRequest request);
    Task<ApiResponse<OtherPersonResponse>> GetByIdAsync(int id);
    Task<ApiResponse<OtherPersonResponse>> CreateAsync(CreateOtherPersonRequest request);
    Task<ApiResponse<OtherPersonResponse>> UpdateAsync(int id, UpdateOtherPersonRequest request);
    Task<ApiResponse<bool>>                DeleteAsync(int id);
}
