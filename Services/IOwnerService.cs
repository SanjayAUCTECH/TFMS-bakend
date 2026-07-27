using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IOwnerService
{
    Task<ApiResponse<IEnumerable<OwnerResponse>>> GetAllAsync(OwnerListRequest request);
    Task<ApiResponse<OwnerResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<OwnerResponse>>              CreateAsync(CreateOwnerRequest request, int? userId = null);
    Task<ApiResponse<OwnerResponse>>              UpdateAsync(int id, UpdateOwnerRequest request, int? userId = null);
    Task<ApiResponse<bool>>                       DeleteAsync(int id, int? userId = null);
}
