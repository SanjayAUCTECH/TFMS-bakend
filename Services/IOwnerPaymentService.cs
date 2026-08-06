using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IOwnerPaymentService
{
    // ── List & Summary ────────────────────────────────────────────────────────
    Task<ApiResponse<IEnumerable<OwnerContractListItemResponse>>> GetAllContractsAsync(OwnerPaymentListRequest request);
    Task<ApiResponse<OwnerPaymentSummaryResponse>> GetSummaryAsync(int ownerContractId);

    // ── Payment History ───────────────────────────────────────────────────────
    Task<ApiResponse<IEnumerable<OwnerPaymentHistoryResponse>>> GetHistoryAsync(int ownerContractId);
    Task<ApiResponse<OwnerPaymentHistoryResponse>> GetPaymentByIdAsync(int txnId);

    // ── Installments ──────────────────────────────────────────────────────────
    Task<ApiResponse<IEnumerable<OwnerInstallmentDetailResponse>>> GetInstallmentsAsync(int ownerContractId);
    Task<ApiResponse<IEnumerable<OwnerInstallmentMonthResponse>>> GetInstallmentMonthsAsync(int ownerContractId);

    // ── Ledger ────────────────────────────────────────────────────────────────
    Task<ApiResponse<IEnumerable<OwnerLedgerEntryResponse>>> GetLedgerAsync(int ownerContractId);

    // ── Pay / Update / Delete ─────────────────────────────────────────────────
    Task<ApiResponse<object>> PayOwnerAsync(PayOwnerRequest request);
    Task<ApiResponse<object>> UpdatePaymentAsync(int txnId, UpdateOwnerPaymentRequest request);
    Task<ApiResponse<bool>> DeletePaymentAsync(int txnId, int? deletedBy);

    // ── Voucher ───────────────────────────────────────────────────────────────
    Task<ApiResponse<OwnerPaymentVoucherResponse>> GetVoucherAsync(int txnId);

    // ── Edit Data (payment + monthly breakdown by txnId) ─────────────────────
    Task<ApiResponse<OwnerPaymentEditDataResponse>> GetPaymentEditDataAsync(int txnId);

    // ── Security Deposit ─────────────────────────────────────────────────────
    Task<ApiResponse<OwnerSecurityDepositStatusResponse>> GetSecurityDepositStatusAsync(int ownerContractId);
    Task<ApiResponse<object>> PaySecurityDepositAsync(PayOwnerSecurityDepositRequest request);
    Task<ApiResponse<object>> SettleSecurityDepositAsync(SettleOwnerSecurityDepositRequest request);
}
