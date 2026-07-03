using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IPaymentService
{
    Task<ApiResponse<IEnumerable<PaymentResponse>>> GetAllAsync(PaymentListRequest request);
    Task<ApiResponse<PaymentResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<IEnumerable<PaymentResponse>>> GetByContractIdAsync(string contractId);
    Task<ApiResponse<bool>>                         RecordPaymentAsync(RecordPaymentRequest request);
}
