using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IPaymentModeRepository
{
    Task<IEnumerable<PaymentMode>> GetAllAsync(string? status = null);
    Task<PaymentMode?> GetByIdAsync(int id);
    Task<int>  CreateAsync(PaymentMode pm);
    Task<bool> UpdateAsync(PaymentMode pm);
    Task<bool> DeleteAsync(int id);
}
