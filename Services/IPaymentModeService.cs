using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IPaymentModeService
{
    Task<ApiResponse<IEnumerable<PaymentModeResponse>>> GetAllAsync(string? status = null);
    Task<ApiResponse<PaymentModeResponse>> GetByIdAsync(int id);
    Task<ApiResponse<PaymentModeResponse>> CreateAsync(CreatePaymentModeRequest request);
    Task<ApiResponse<PaymentModeResponse>> UpdateAsync(int id, UpdatePaymentModeRequest request);
    Task<ApiResponse<bool>>                DeleteAsync(int id);
}
