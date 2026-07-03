using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IAccountsHeadRepository
{
    Task<(IEnumerable<AccountsHead> Data, int TotalRecords)> GetAllAsync(AccountsHeadListRequest request);
    Task<IEnumerable<AccountsHead>> GetAllActiveAsync();
    Task<AccountsHead?> GetByIdAsync(int id);
    Task<int>  CreateAsync(AccountsHead ah);
    Task<bool> UpdateAsync(AccountsHead ah);
    Task<bool> DeleteAsync(int id);
}
