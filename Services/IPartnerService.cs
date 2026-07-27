using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IPartnerService
{
    Task<ApiResponse<IEnumerable<PartnerResponse>>> GetAllAsync(PartnerListRequest request);
    Task<ApiResponse<PartnerResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<PartnerResponse>>              CreateAsync(CreatePartnerRequest request, int? userId = null);
    Task<ApiResponse<PartnerResponse>>              UpdateAsync(int id, UpdatePartnerRequest request, int? userId = null);
    Task<ApiResponse<bool>>                         DeleteAsync(int id, int? userId = null);
}
