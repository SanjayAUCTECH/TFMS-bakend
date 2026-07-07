using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IExpenseRepository
{
    Task<(IEnumerable<Expense> Data, int TotalRecords)> GetAllAsync(ExpenseListRequest request);
    Task<Expense?> GetByIdAsync(int id);
    Task<int>      CreateAsync(Expense expense);
    Task<bool>     UpdateAsync(Expense expense);
    Task<bool>     DeleteAsync(int id);
    Task<bool>     ExistsAsync(int id);
    Task<object>   GetStatsAsync();
}
