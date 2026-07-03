using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IExpenseService
{
    Task<ApiResponse<IEnumerable<ExpenseResponse>>> GetAllAsync(ExpenseListRequest request);
    Task<ApiResponse<ExpenseResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<ExpenseResponse>>              CreateAsync(CreateExpenseRequest request);
    Task<ApiResponse<ExpenseResponse>>              UpdateAsync(int id, UpdateExpenseRequest request);
    Task<ApiResponse<bool>>                         DeleteAsync(int id);
}
