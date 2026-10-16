using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IAlertTimeService
{
    Task<ApiResponse<IEnumerable<AlertTimeResponse>>> GetAllAsync(AlertTimeListRequest request);
    Task<ApiResponse<AlertTimeResponse>> GetByIdAsync(int id);
    Task<ApiResponse<AlertTimeResponse>> CreateAsync(CreateAlertTimeRequest request, int? userId);
    Task<ApiResponse<AlertTimeResponse>> UpdateAsync(int id, UpdateAlertTimeRequest request, int? userId);
    Task<ApiResponse<bool>> DeleteAsync(int id, int? userId);
}
