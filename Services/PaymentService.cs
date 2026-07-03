using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class PaymentService : IPaymentService
{
    private readonly IPaymentRepository     _repo;
    private readonly IPaymentModeRepository _modeRepo;
    private readonly IFundPoolRepository    _fundRepo;

    public PaymentService(IPaymentRepository repo, IPaymentModeRepository modeRepo, IFundPoolRepository fundRepo)
    {
        _repo = repo; _modeRepo = modeRepo; _fundRepo = fundRepo;
    }

    public async Task<ApiResponse<IEnumerable<PaymentResponse>>> GetAllAsync(PaymentListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<PaymentResponse>>.Ok(
            data.Select(ToResponse), "Payments retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<PaymentResponse>> GetByIdAsync(int id)
    {
        var p = await _repo.GetByIdAsync(id);
        return p == null ? ApiResponse<PaymentResponse>.Fail("Payment not found.") : ApiResponse<PaymentResponse>.Ok(ToResponse(p));
    }

    public async Task<ApiResponse<IEnumerable<PaymentResponse>>> GetByContractIdAsync(string contractId)
        => ApiResponse<IEnumerable<PaymentResponse>>.Ok((await _repo.GetByContractIdAsync(contractId)).Select(ToResponse));

    public async Task<ApiResponse<bool>> RecordPaymentAsync(RecordPaymentRequest request)
    {
        var pm = await _modeRepo.GetByIdAsync(request.PaymentModeId);
        if (pm == null) return ApiResponse<bool>.Fail("Payment mode not found.");

        string fundPoolName = string.Empty;
        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp == null) return ApiResponse<bool>.Fail("Fund Pool not found.");
            fundPoolName = fp.Name;
        }

        var result = await _repo.RecordPaymentAsync(new Payment
        {
            ContractId      = request.ContractId,
            InstallmentNo   = request.InstallmentNo,
            PaidAmount      = request.Amount,
            PaidDate        = request.PaidDate,
            PaymentModeId   = request.PaymentModeId,
            PaymentMode     = pm.Name,
            ChequeNumber    = request.ChequeNumber,
            ClearanceDate   = request.ClearanceDate,
            Description     = request.Description,
            ReceivedBy      = request.ReceivedBy,
            ReceivedContact = request.ReceivedContact,
            FundPoolId      = request.FundPoolId,
            FundPoolName    = fundPoolName,
            IssuedBy        = request.IssuedBy,
        });
        return result
            ? ApiResponse<bool>.Ok(true, "Payment recorded successfully.")
            : ApiResponse<bool>.Fail("Payment recording failed. Check contract and installment number.");
    }

    private static PaymentResponse ToResponse(Payment p) => new()
    {
        Id = p.Id, ContractId = p.ContractId, InstallmentNo = p.InstallmentNo,
        Amount = p.Amount, DueDate = p.DueDate, PaidAmount = p.PaidAmount,
        BalanceAmount = p.Amount - p.PaidAmount,
        PaidDate = p.PaidDate, Status = p.Status, PaymentMode = p.PaymentMode,
        PaymentModeId = p.PaymentModeId, ChequeNumber = p.ChequeNumber,
        ClearanceDate = p.ClearanceDate, Description = p.Description,
        ReceivedBy = p.ReceivedBy, ReceivedContact = p.ReceivedContact,
        FundPoolId = p.FundPoolId, FundPoolName = p.FundPoolName, IssuedBy = p.IssuedBy,
        DueMonth = p.DueDate.ToString("MMMM"), DueYear = p.DueDate.Year,
    };
}
