using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IPartnerService
{
    Task<ApiResponse<IEnumerable<PartnerResponse>>> GetAllAsync(PartnerListRequest request);
    Task<ApiResponse<PartnerResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<PartnerResponse>>              CreateAsync(CreatePartnerRequest request);
    Task<ApiResponse<PartnerResponse>>              UpdateAsync(int id, UpdatePartnerRequest request);
    Task<ApiResponse<bool>>                         DeleteAsync(int id);
}
