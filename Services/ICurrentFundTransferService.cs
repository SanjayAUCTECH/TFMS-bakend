using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ICurrentFundTransferService
{
    Task<ApiResponse<IEnumerable<CurrentFundTransferResponse>>> GetAllAsync(CurrentFundTransferListRequest request);
    Task<ApiResponse<CurrentFundTransferResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<CurrentFundTransferResponse>>              CreateAsync(CreateCurrentFundTransferRequest request, string? addedBy);
    Task<ApiResponse<CurrentFundTransferResponse>>              UpdateAsync(int id, UpdateCurrentFundTransferRequest request, string? updatedBy);
    Task<ApiResponse<bool>>                                     DeleteAsync(int id, string? deletedBy);
}
