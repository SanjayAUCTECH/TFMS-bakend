using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ICompanyAssetRepository
{
    Task<(IEnumerable<CompanyAssetResponse> Data, int TotalRecords)> GetAllAsync(CompanyAssetListRequest req);
    Task<CompanyAssetResponse?> GetByIdAsync(int id);
    Task<int>  CreateAsync(CreateCompanyAssetRequest req, string? documentUrl, int? addedBy = null);
    Task<bool> UpdateAsync(int id, UpdateCompanyAssetRequest req, string? documentUrl);
    Task<bool> DeleteAsync(int id, int? deletedBy = null);
    Task<bool> ExistsAsync(int id);
}
