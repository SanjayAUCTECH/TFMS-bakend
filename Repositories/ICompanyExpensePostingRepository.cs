using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ICompanyExpensePostingRepository
{
    Task<(IEnumerable<CompanyExpensePosting> Data, int Total)> GetAllAsync(CompanyExpensePostingListRequest request);
    Task<CompanyExpensePosting?>                               GetByIdAsync(int id);
    Task<int>                                                  CreateAsync(CompanyExpensePosting model);
    Task<bool>                                                 UpdateAsync(CompanyExpensePosting model);
    Task<bool>                                                 DeleteAsync(int id, string? deletedBy);
    Task<IEnumerable<CompanyExpenseSummaryResponse>>           GetSummaryAsync(int? salonId, string? dateFrom, string? dateTo);
}
