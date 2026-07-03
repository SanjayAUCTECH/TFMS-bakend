using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IFundPoolRepository
{
    Task<(IEnumerable<FundPool> Data, int TotalRecords)> GetAllAsync(FundPoolListRequest request);
    Task<IEnumerable<FundPool>> GetAllActiveAsync();
    Task<FundPool?> GetByIdAsync(int id);
    Task<int>  CreateAsync(FundPool fp);
    Task<bool> UpdateAsync(FundPool fp);
    Task<bool> DeleteAsync(int id);
}
