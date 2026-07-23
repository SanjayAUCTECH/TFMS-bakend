using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class WaiverService : IWaiverService
{
    private readonly IWaiverRepository  _repo;
    private readonly ITenantRepository  _tenantRepo;
    private readonly IPaymentRepository _paymentRepo;

    public WaiverService(IWaiverRepository repo, ITenantRepository tenantRepo, IPaymentRepository paymentRepo)
    {
        _repo = repo; _tenantRepo = tenantRepo; _paymentRepo = paymentRepo;
    }

    public async Task<ApiResponse<IEnumerable<WaiverResponse>>> GetAllAsync(WaiverListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<WaiverResponse>>.Ok(
            data.Select(ToResponse), "Waivers retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<WaiverResponse>> GetByIdAsync(int id)
    {
        var w = await _repo.GetByIdAsync(id);
        return w == null ? ApiResponse<WaiverResponse>.Fail("Waiver not found.") : ApiResponse<WaiverResponse>.Ok(ToResponse(w));
    }

    public async Task<ApiResponse<WaiverResponse>> CreateAsync(CreateWaiverRequest request)
    {
        if (!await _tenantRepo.ExistsAsync(request.TenantId ?? 0))
            return ApiResponse<WaiverResponse>.Fail("Tenant not found.");

        var payments    = await _paymentRepo.GetByContractIdAsync(request.ContractId);
        var installment = payments.FirstOrDefault(p => p.InstallmentNo == (request.InstallmentNo ?? 0));
        if (installment == null)
            return ApiResponse<WaiverResponse>.Fail("Installment not found.");
        if (installment.Status == "Paid")
            return ApiResponse<WaiverResponse>.Fail("Cannot waive a fully paid installment.");
        if (request.WaiverAmount > installment.Amount)
            return ApiResponse<WaiverResponse>.Fail("Waiver amount cannot exceed the installment amount.");

        // Use new room-wise SP if RoomWaivers provided
        if (request.RoomWaivers != null && request.RoomWaivers.Count > 0)
        {
            var roomWaiversJson = System.Text.Json.JsonSerializer.Serialize(
                request.RoomWaivers,
                new System.Text.Json.JsonSerializerOptions { PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase });

            var id2 = await _repo.CreateWithRoomsAsync(new Waiver
            {
                TenantId       = request.TenantId ?? 0,
                ContractId     = request.ContractId,
                InstallmentNo  = request.InstallmentNo ?? 0,
                OriginalAmount = installment.Amount,
                WaiverAmount   = request.WaiverAmount,
                BalanceAmount  = installment.Amount - request.WaiverAmount,
                Remark         = request.Remark,
                WaiverDate     = request.WaiverDate,
                CreatedBy      = request.CreatedBy,
            }, roomWaiversJson);
            return ApiResponse<WaiverResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id2))!), "Waiver created.");
        }

        // Original flow (no rooms)
        var id = await _repo.CreateAsync(new Waiver
        {
            TenantId       = request.TenantId ?? 0,
            ContractId     = request.ContractId,
            InstallmentNo  = request.InstallmentNo ?? 0,
            OriginalAmount = installment.Amount,
            WaiverAmount   = request.WaiverAmount,
            BalanceAmount  = installment.Amount - request.WaiverAmount,
            Remark         = request.Remark,
            WaiverDate     = request.WaiverDate,
            CreatedBy      = request.CreatedBy,
        });
        return ApiResponse<WaiverResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Waiver created.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Waiver not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static WaiverResponse ToResponse(Waiver w) => new()
    {
        Id = w.Id, TenantId = w.TenantId, TenantName = w.TenantName,
        ContractId = w.ContractId, InstallmentNo = w.InstallmentNo,
        OriginalAmount = w.OriginalAmount, WaiverAmount = w.WaiverAmount,
        BalanceAmount = w.BalanceAmount, Remark = w.Remark, WaiverDate = w.WaiverDate,
    };
}
