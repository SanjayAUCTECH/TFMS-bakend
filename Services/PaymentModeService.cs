using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class PaymentModeService : IPaymentModeService
{
    private readonly IPaymentModeRepository _repo;
    public PaymentModeService(IPaymentModeRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<PaymentModeResponse>>> GetAllAsync(string? status = null)
    {
        var data = await _repo.GetAllAsync(status);
        return ApiResponse<IEnumerable<PaymentModeResponse>>.Ok(data.Select(p => new PaymentModeResponse { Id = p.Id, Name = p.Name, Status = p.Status }));
    }

    public async Task<ApiResponse<PaymentModeResponse>> GetByIdAsync(int id)
    {
        var pm = await _repo.GetByIdAsync(id);
        return pm == null ? ApiResponse<PaymentModeResponse>.Fail("Not found.") : ApiResponse<PaymentModeResponse>.Ok(new PaymentModeResponse { Id = pm.Id, Name = pm.Name, Status = pm.Status });
    }

    public async Task<ApiResponse<PaymentModeResponse>> CreateAsync(CreatePaymentModeRequest request, int? userId = null)
    {
        var id = await _repo.CreateAsync(new PaymentMode { Name = request.Name?.Trim() ?? "", Status = request.Status, AddedBy = userId });
        var pm = await _repo.GetByIdAsync(id);
        return ApiResponse<PaymentModeResponse>.Ok(new PaymentModeResponse { Id = pm!.Id, Name = pm.Name, Status = pm.Status }, "Payment Mode created.");
    }

    public async Task<ApiResponse<PaymentModeResponse>> UpdateAsync(int id, UpdatePaymentModeRequest request, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<PaymentModeResponse>.Fail("Not found.");
        await _repo.UpdateAsync(new PaymentMode { Id = id, Name = request.Name.Trim(), Status = request.Status, UpdatedBy = userId });
        var pm = await _repo.GetByIdAsync(id);
        return ApiResponse<PaymentModeResponse>.Ok(new PaymentModeResponse { Id = pm!.Id, Name = pm.Name, Status = pm.Status }, "Updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id, userId) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }
}
