using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IPaymentModeService
{
    Task<ApiResponse<IEnumerable<PaymentModeResponse>>> GetAllAsync(string? status = null);
    Task<ApiResponse<PaymentModeResponse>> GetByIdAsync(int id);
    Task<ApiResponse<PaymentModeResponse>> CreateAsync(CreatePaymentModeRequest request, int? userId = null);
    Task<ApiResponse<PaymentModeResponse>> UpdateAsync(int id, UpdatePaymentModeRequest request, int? userId = null);
    Task<ApiResponse<bool>>                DeleteAsync(int id, int? userId = null);
}
