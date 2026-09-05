using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ICompanyExpensePostingService
{
    Task<ApiResponse<IEnumerable<CompanyExpensePostingResponse>>> GetAllAsync(CompanyExpensePostingListRequest request);
    Task<ApiResponse<CompanyExpensePostingResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<CompanyExpensePostingResponse>>              CreateAsync(CreateCompanyExpensePostingRequest request, string? addedBy);
    Task<ApiResponse<CompanyExpensePostingResponse>>              UpdateAsync(int id, UpdateCompanyExpensePostingRequest request, int? userId);
    Task<ApiResponse<bool>>                                       DeleteAsync(int id, string? deletedBy);
    Task<ApiResponse<IEnumerable<CompanyExpenseSummaryResponse>>> GetSummaryAsync(int? salonId, string? dateFrom, string? dateTo);
}
