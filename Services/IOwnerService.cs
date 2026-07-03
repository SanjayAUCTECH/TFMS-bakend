using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IOwnerService
{
    Task<ApiResponse<IEnumerable<OwnerResponse>>> GetAllAsync(OwnerListRequest request);
    Task<ApiResponse<OwnerResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<OwnerResponse>>              CreateAsync(CreateOwnerRequest request);
    Task<ApiResponse<OwnerResponse>>              UpdateAsync(int id, UpdateOwnerRequest request);
    Task<ApiResponse<bool>>                       DeleteAsync(int id);
}
