using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IBufferFundTransferService
{
    Task<ApiResponse<IEnumerable<BufferFundTransferResponse>>> GetAllAsync(BufferFundTransferListRequest request);
    Task<ApiResponse<BufferFundTransferResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<BufferFundTransferResponse>>              CreateAsync(CreateBufferFundTransferRequest request, string? addedBy);
    Task<ApiResponse<BufferFundTransferResponse>>              UpdateAsync(int id, UpdateBufferFundTransferRequest request, string? updatedBy);
    Task<ApiResponse<bool>>                                    DeleteAsync(int id, string? deletedBy);
}
