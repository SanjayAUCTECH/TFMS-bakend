using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IWaiverService
{
    Task<ApiResponse<IEnumerable<WaiverResponse>>> GetAllAsync(WaiverListRequest request);
    Task<ApiResponse<WaiverResponse>> GetByIdAsync(int id);
    Task<ApiResponse<WaiverResponse>> CreateAsync(CreateWaiverRequest request, int? userId = null);
    Task<ApiResponse<bool>>           DeleteAsync(int id, int? userId = null);
}
