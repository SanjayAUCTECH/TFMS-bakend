using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ICompanyRepository
{
    Task<int> CreateAsync(CreateCompanyRequest request, string? addedBy);
    Task<(IEnumerable<CompanyResponse> Companies, int TotalRecords)> GetAllAsync(int pageNumber, int pageSize, string? search, string? status);
    Task<CompanyResponse?> GetByIdAsync(int id);
    Task UpdateAsync(int id, UpdateCompanyRequest request, string? updatedBy);
    Task DeleteAsync(int id, string? deletedBy);
}
