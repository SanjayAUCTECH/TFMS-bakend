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
    private readonly IIncomeRepository      _incomeRepo;
    private readonly ITxnRecordRepository   _txnRepo;

    public PaymentService(
        IPaymentRepository     repo,
        IPaymentModeRepository modeRepo,
        IFundPoolRepository    fundRepo,
        IIncomeRepository      incomeRepo,
        ITxnRecordRepository   txnRepo)
    {
        _repo       = repo;
        _modeRepo   = modeRepo;
        _fundRepo   = fundRepo;
        _incomeRepo = incomeRepo;
        _txnRepo    = txnRepo;
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
        return p == null
            ? ApiResponse<PaymentResponse>.Fail("Payment not found.")
            : ApiResponse<PaymentResponse>.Ok(ToResponse(p));
    }

    public async Task<ApiResponse<IEnumerable<PaymentResponse>>> GetByContractIdAsync(string contractId)
        => ApiResponse<IEnumerable<PaymentResponse>>.Ok(
            (await _repo.GetByContractIdAsync(contractId)).Select(ToResponse));

    public async Task<ApiResponse<bool>> RecordPaymentAsync(RecordPaymentRequest request)
    {
        // Resolve payment mode name
        string pmName = request.PaymentMode;
        if (request.PaymentModeId.HasValue)
        {
            var pm = await _modeRepo.GetByIdAsync(request.PaymentModeId.Value);
            if (pm != null) pmName = pm.Name;
        }

        // Resolve fund pool name + code
        string fundPoolName = request.FundPoolName;
        string fundPoolCode = "";
        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp != null) { fundPoolName = fp.Name; fundPoolCode = fp.Code; }
        }

        // 1. Record payment in ContractInstallments
        var result = await _repo.RecordPaymentAsync(new Payment
        {
            ContractId      = request.ContractId,
            InstallmentNo   = request.InstallmentNo,
            PaidAmount      = request.PaidAmount,
            PaidDate        = request.PaidDate,
            PaymentModeId   = request.PaymentModeId,
            PaymentMode     = pmName,
            ChequeNumber    = request.ChequeNumber,
            ClearanceDate   = request.ClearanceDate,
            Description     = request.Description,
            ReceivedBy      = request.ReceivedBy,
            ReceivedContact = request.ReceivedContact,
            FundPoolId      = request.FundPoolId,
            FundPoolName    = fundPoolName,
            IssuedBy        = request.IssuedBy,
        });

        if (!result)
            return ApiResponse<bool>.Fail("Payment recording failed. Check contract and installment number.");

        // Income + TxnRecord are auto-created inside sp_RecordPayment (DB transaction)
        return ApiResponse<bool>.Ok(true, "Payment recorded successfully.");
    }

    private static PaymentResponse ToResponse(Payment p) => new()
    {
        Id              = p.Id,
        ContractId      = p.ContractId,
        InstallmentNo   = p.InstallmentNo,
        Amount          = p.Amount,
        DueDate         = p.DueDate,
        PaidAmount      = p.PaidAmount,
        BalanceAmount   = p.Amount - p.PaidAmount,
        PaidDate        = p.PaidDate,
        Status          = p.Status,
        PaymentMode     = p.PaymentMode,
        PaymentModeId   = p.PaymentModeId,
        ChequeNumber    = p.ChequeNumber,
        ClearanceDate   = p.ClearanceDate,
        Description     = p.Description,
        ReceivedBy      = p.ReceivedBy,
        ReceivedContact = p.ReceivedContact,
        FundPoolId      = p.FundPoolId,
        FundPoolName    = p.FundPoolName,
        IssuedBy        = p.IssuedBy,
        DueMonth        = p.DueDate.ToString("MMMM"),
        DueYear         = p.DueDate.Year,
    };
}
