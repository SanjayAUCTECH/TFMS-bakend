using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IOutsourceMoneyService
{
    Task<ApiResponse<IEnumerable<OutsourceMoneyResponse>>> GetAllAsync(OutsourceMoneyListRequest request);
    Task<ApiResponse<OutsourceMoneyResponse>> GetByIdAsync(int id);
    Task<ApiResponse<OutsourceMoneyResponse>> CreateAsync(CreateOutsourceMoneyRequest request, int? userId = null);
    Task<ApiResponse<OutsourceMoneyResponse>> UpdateAsync(int id, UpdateOutsourceMoneyRequest request, int? userId = null);
    Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null);
}
