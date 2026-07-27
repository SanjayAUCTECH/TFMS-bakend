using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IIncomeService
{
    Task<ApiResponse<IEnumerable<IncomeResponse>>> GetAllAsync(IncomeListRequest request);
    Task<ApiResponse<IncomeResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<IncomeResponse>>              CreateAsync(CreateIncomeRequest request, int? userId = null);
    Task<ApiResponse<IncomeResponse>>              UpdateAsync(int id, UpdateIncomeRequest request, int? userId = null);
    Task<ApiResponse<bool>>                        DeleteAsync(int id, int? userId = null);
}
