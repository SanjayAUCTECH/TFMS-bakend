using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IOwnerPaymentRepository
{
    // ── List & Summary ────────────────────────────────────────────────────────
    Task<IEnumerable<OwnerContractListItemResponse>> GetAllContractsAsync(OwnerPaymentListRequest request);
    Task<OwnerPaymentSummaryResponse?> GetSummaryAsync(int ownerContractId);

    // ── Payment History ───────────────────────────────────────────────────────
    Task<IEnumerable<OwnerPaymentHistoryResponse>> GetHistoryAsync(int ownerContractId);
    Task<OwnerPaymentHistoryResponse?> GetPaymentByIdAsync(int txnId);

    // ── Installments ──────────────────────────────────────────────────────────
    Task<IEnumerable<OwnerInstallmentDetailResponse>> GetInstallmentsAsync(int ownerContractId);
    Task<IEnumerable<OwnerInstallmentMonthResponse>> GetInstallmentMonthsAsync(int ownerContractId);

    // ── Ledger ────────────────────────────────────────────────────────────────
    Task<IEnumerable<OwnerLedgerEntryResponse>> GetLedgerAsync(int ownerContractId);

    // ── Pay / Update / Delete ────────────────────────────────────────────────
    Task<(bool Success, string TxnCode, int? ExpenseId)> PayOwnerAsync(PayOwnerRequest request);
    Task<(bool Success, string TxnCode)> UpdatePaymentAsync(int txnId, UpdateOwnerPaymentRequest request);
    Task<bool> DeletePaymentAsync(int txnId, int? deletedBy);

    // ── Voucher ───────────────────────────────────────────────────────────────
    Task<OwnerPaymentVoucherResponse?> GetVoucherAsync(int txnId);

    // ── Get Payment Detail with Monthly Breakdown (for Edit pre-fill) ────────
    Task<OwnerPaymentEditDataResponse?> GetPaymentEditDataAsync(int txnId);

    // ── Security Deposit ─────────────────────────────────────────────────────
    Task<OwnerSecurityDepositStatusResponse?> GetSecurityDepositStatusAsync(int ownerContractId);
    Task<(bool Success, decimal NewPaid, string NewStatus)> PaySecurityDepositAsync(PayOwnerSecurityDepositRequest request);
    Task<(bool Success, string NewStatus)> SettleSecurityDepositAsync(SettleOwnerSecurityDepositRequest request);
}
