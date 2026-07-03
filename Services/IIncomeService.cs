using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IIncomeService
{
    Task<ApiResponse<IEnumerable<IncomeResponse>>> GetAllAsync(IncomeListRequest request);
    Task<ApiResponse<IncomeResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<IncomeResponse>>              CreateAsync(CreateIncomeRequest request);
    Task<ApiResponse<IncomeResponse>>              UpdateAsync(int id, UpdateIncomeRequest request);
    Task<ApiResponse<bool>>                        DeleteAsync(int id);
}
