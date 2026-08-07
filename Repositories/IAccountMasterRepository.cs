using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IAccountMasterRepository
{
    Task<(IEnumerable<AccountMaster> Data, int TotalRecords)> GetAllAsync(AccountMasterListRequest request);
    Task<AccountMaster?> GetByIdAsync(int id);
    Task<int> CreateAsync(AccountMaster master, List<AccountMasterHeadItem> heads, int? userId, string? requestedVoucherNo = null);
    Task<bool> UpdateAsync(int id, AccountMaster master, List<AccountMasterHeadItem> heads, int? userId);
    Task<bool> DeleteAsync(int id, int? userId);
    Task<List<(int Id, string PaymentType, string Head, decimal Amount, string Purpose, string RefId, int? CampId, string CampName)>> GetHeadsByAccountIdAsync(string accountId);
}
