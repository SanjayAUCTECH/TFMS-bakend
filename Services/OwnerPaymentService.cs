using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class OwnerPaymentService : IOwnerPaymentService
{
    private readonly IOwnerPaymentRepository _repo;
    private readonly IPaymentModeRepository  _modeRepo;
    private readonly IFundPoolRepository     _fundRepo;
    private readonly ILogger<OwnerPaymentService> _logger;

    public OwnerPaymentService(
        IOwnerPaymentRepository repo,
        IPaymentModeRepository  modeRepo,
        IFundPoolRepository     fundRepo,
        ILogger<OwnerPaymentService> logger)
    {
        _repo     = repo;
        _modeRepo = modeRepo;
        _fundRepo = fundRepo;
        _logger   = logger;
    }

    // ── Get All Contracts ─────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<OwnerContractListItemResponse>>> GetAllContractsAsync(OwnerPaymentListRequest request)
    {
        var data = await _repo.GetAllContractsAsync(request);
        return ApiResponse<IEnumerable<OwnerContractListItemResponse>>.Ok(data, "Owner contracts retrieved.");
    }

    // ── Summary ───────────────────────────────────────────────────────────────
    public async Task<ApiResponse<OwnerPaymentSummaryResponse>> GetSummaryAsync(int ownerContractId)
    {
        var data = await _repo.GetSummaryAsync(ownerContractId);
        return data == null
            ? ApiResponse<OwnerPaymentSummaryResponse>.Fail("Owner contract not found.")
            : ApiResponse<OwnerPaymentSummaryResponse>.Ok(data, "Owner payment summary retrieved.");
    }

    // ── History ───────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<OwnerPaymentHistoryResponse>>> GetHistoryAsync(int ownerContractId)
    {
        var data = await _repo.GetHistoryAsync(ownerContractId);
        return ApiResponse<IEnumerable<OwnerPaymentHistoryResponse>>.Ok(data, "Owner payment history retrieved.");
    }

    public async Task<ApiResponse<OwnerPaymentHistoryResponse>> GetPaymentByIdAsync(int txnId)
    {
        var data = await _repo.GetPaymentByIdAsync(txnId);
        return data == null
            ? ApiResponse<OwnerPaymentHistoryResponse>.Fail("Payment not found.")
            : ApiResponse<OwnerPaymentHistoryResponse>.Ok(data, "Payment retrieved.");
    }

    // ── Installments ──────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<OwnerInstallmentDetailResponse>>> GetInstallmentsAsync(int ownerContractId)
    {
        var data = await _repo.GetInstallmentsAsync(ownerContractId);
        return ApiResponse<IEnumerable<OwnerInstallmentDetailResponse>>.Ok(data, "Installments retrieved.");
    }

    public async Task<ApiResponse<IEnumerable<OwnerInstallmentMonthResponse>>> GetInstallmentMonthsAsync(int ownerContractId)
    {
        var data = await _repo.GetInstallmentMonthsAsync(ownerContractId);
        return ApiResponse<IEnumerable<OwnerInstallmentMonthResponse>>.Ok(data, "Installment months retrieved.");
    }

    // ── Ledger ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<OwnerLedgerEntryResponse>>> GetLedgerAsync(int ownerContractId)
    {
        var data = await _repo.GetLedgerAsync(ownerContractId);
        return ApiResponse<IEnumerable<OwnerLedgerEntryResponse>>.Ok(data, "Ledger retrieved.");
    }

    // ── Pay Owner ─────────────────────────────────────────────────────────────
    public async Task<ApiResponse<object>> PayOwnerAsync(PayOwnerRequest request)
    {
        if (request.Amount <= 0)
            return ApiResponse<object>.Fail("Amount must be greater than 0.");

        if (request.PaymentModeId.HasValue)
        {
            var pm = await _modeRepo.GetByIdAsync(request.PaymentModeId.Value);
            if (pm != null) request.PaymentMode = pm.Name;
        }

        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp != null)
            {
                request.FundPoolName = fp.Name;
                if (fp.Balance < request.Amount)
                    return ApiResponse<object>.Fail($"Insufficient fund pool balance. Available: {fp.Balance}, Required: {request.Amount}");
            }
        }

        var (success, txnCode, expenseId) = await _repo.PayOwnerAsync(request);
        if (!success)
            return ApiResponse<object>.Fail("Payment failed. Please check owner contract and try again.");

        return ApiResponse<object>.Ok(new
        {
            txnCode,
            expenseId,
            ownerContractId = request.OwnerContractId,
            amount = request.Amount,
            paidDate = request.PaidDate.ToString("yyyy-MM-dd"),
        }, $"Payment of {request.Amount} to owner recorded successfully.");
    }

    // ── Update Payment ────────────────────────────────────────────────────────
    public async Task<ApiResponse<object>> UpdatePaymentAsync(int txnId, UpdateOwnerPaymentRequest request)
    {
        if (request.Amount <= 0)
            return ApiResponse<object>.Fail("Amount must be greater than 0.");

        if (request.PaymentModeId.HasValue)
        {
            var pm = await _modeRepo.GetByIdAsync(request.PaymentModeId.Value);
            if (pm != null) request.PaymentMode = pm.Name;
        }

        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp != null)
            {
                request.FundPoolName = fp.Name;
                if (fp.Balance < request.Amount)
                    return ApiResponse<object>.Fail($"Insufficient fund pool balance. Available: {fp.Balance}, Required: {request.Amount}");
            }
        }

        var (success, txnCode) = await _repo.UpdatePaymentAsync(txnId, request);
        if (!success)
            return ApiResponse<object>.Fail("Update failed. Payment not found or error occurred.");

        return ApiResponse<object>.Ok(new { txnId, txnCode, amount = request.Amount },
            "Owner payment updated successfully.");
    }

    // ── Delete Payment ────────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> DeletePaymentAsync(int txnId, int? deletedBy)
    {
        var result = await _repo.DeletePaymentAsync(txnId, deletedBy);
        return result
            ? ApiResponse<bool>.Ok(true, "Owner payment reversed successfully.")
            : ApiResponse<bool>.Fail("Failed to delete/reverse payment.");
    }

    // ── Voucher ───────────────────────────────────────────────────────────────
    public async Task<ApiResponse<OwnerPaymentVoucherResponse>> GetVoucherAsync(int txnId)
    {
        var data = await _repo.GetVoucherAsync(txnId);
        return data == null
            ? ApiResponse<OwnerPaymentVoucherResponse>.Fail("Transaction not found.")
            : ApiResponse<OwnerPaymentVoucherResponse>.Ok(data, "Voucher data retrieved.");
    }

    // ── Security Deposit — Status ─────────────────────────────────────────────
    public async Task<ApiResponse<OwnerSecurityDepositStatusResponse>> GetSecurityDepositStatusAsync(int ownerContractId)
    {
        var data = await _repo.GetSecurityDepositStatusAsync(ownerContractId);
        return data == null
            ? ApiResponse<OwnerSecurityDepositStatusResponse>.Fail("Owner contract not found.")
            : ApiResponse<OwnerSecurityDepositStatusResponse>.Ok(data, "Security deposit status retrieved.");
    }

    // ── Security Deposit — Pay ────────────────────────────────────────────────
    public async Task<ApiResponse<object>> PaySecurityDepositAsync(PayOwnerSecurityDepositRequest request)
    {
        if (request.Amount <= 0)
            return ApiResponse<object>.Fail("Amount must be greater than 0.");

        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp != null)
            {
                request.FundPoolName = fp.Name;
                if (fp.Balance < request.Amount)
                    return ApiResponse<object>.Fail($"Insufficient fund pool balance. Available: {fp.Balance}, Required: {request.Amount}");
            }
        }

        var (success, newPaid, newStatus) = await _repo.PaySecurityDepositAsync(request);
        if (!success)
            return ApiResponse<object>.Fail("Security deposit payment failed.");

        return ApiResponse<object>.Ok(new
        {
            ownerContractId = request.OwnerContractId,
            amountPaid = request.Amount,
            totalPaid = newPaid,
            status = newStatus,
        }, $"Security deposit of {request.Amount} paid to owner. Status: {newStatus}");
    }

    // ── Security Deposit — Settle ─────────────────────────────────────────────
    public async Task<ApiResponse<object>> SettleSecurityDepositAsync(SettleOwnerSecurityDepositRequest request)
    {
        var totalSettled = request.RecoverAmount + request.AdjustAmount + request.ForfeitAmount;
        if (totalSettled <= 0)
            return ApiResponse<object>.Fail("At least one of RecoverAmount, AdjustAmount, or ForfeitAmount must be > 0.");

        var (success, newStatus) = await _repo.SettleSecurityDepositAsync(request);
        if (!success)
            return ApiResponse<object>.Fail("Security deposit settlement failed.");

        return ApiResponse<object>.Ok(new
        {
            ownerContractId = request.OwnerContractId,
            recovered = request.RecoverAmount,
            adjusted  = request.AdjustAmount,
            forfeited = request.ForfeitAmount,
            totalSettled,
            newStatus,
        }, "Owner security deposit settled successfully.");
    }
}
