using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IOutsourceMoneyRepository
{
    Task<(IEnumerable<OutsourceMoney> data, int total)> GetAllAsync(OutsourceMoneyListRequest request);
    Task<OutsourceMoney?> GetByIdAsync(int id);
    Task<int> CreateAsync(OutsourceMoney entity);
    Task UpdateAsync(OutsourceMoney entity);
    Task<bool> DeleteAsync(int id, int? userId = null);
    Task<object> GetStatsAsync();
}
