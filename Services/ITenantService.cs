using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ITenantService
{
    Task<ApiResponse<IEnumerable<TenantResponse>>> GetAllAsync(TenantListRequest request);
    Task<ApiResponse<TenantResponse>> GetByIdAsync(int id);
    Task<ApiResponse<TenantResponse>> CreateAsync(CreateTenantRequest request, int? userId = null);
    Task<ApiResponse<TenantResponse>> UpdateAsync(int id, UpdateTenantRequest request, int? userId = null);
    Task<ApiResponse<bool>>           DeleteAsync(int id, int? userId = null);
}
