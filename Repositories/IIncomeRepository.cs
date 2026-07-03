using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IIncomeRepository
{
    Task<(IEnumerable<Income> Data, int TotalRecords)> GetAllAsync(IncomeListRequest request);
    Task<Income?> GetByIdAsync(int id);
    Task<int>     CreateAsync(Income income);
    Task<bool>    UpdateAsync(Income income);
    Task<bool>    DeleteAsync(int id);
    Task<bool>    ExistsAsync(int id);
}
