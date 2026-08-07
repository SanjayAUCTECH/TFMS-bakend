using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ITaskAlertService
{
    Task<ApiResponse<IEnumerable<TaskAlertResponse>>> GetAllAsync(TaskAlertListRequest request);
    Task<ApiResponse<TaskAlertResponse>> GetByIdAsync(int id);
    Task<ApiResponse<IEnumerable<TaskAlertActiveResponse>>> GetActiveAlertsAsync(int? assignPersonId = null);
    Task<ApiResponse<TaskAlertResponse>> CreateAsync(CreateTaskAlertRequest request, int? userId = null);
    Task<ApiResponse<TaskAlertResponse>> UpdateAsync(int id, UpdateTaskAlertRequest request, int? userId = null);
    Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null);
}
