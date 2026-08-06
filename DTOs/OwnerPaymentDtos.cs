using System.ComponentModel.DataAnnotations;
using Swashbuckle.AspNetCore.Annotations;

namespace TFMS_software_api.DTOs;

// ══════════════════════════════════════════════════════════════════════════════
//  OWNER PAYMENT DTOs — Company pays Owner (Expense)
// ══════════════════════════════════════════════════════════════════════════════

// ── Requests ──────────────────────────────────────────────────────────────────

/// <summary>Pay owner against installment(s)</summary>
public class PayOwnerRequest
{
    [Required, SwaggerSchema("Owner Contract ID (int)")]
    public int OwnerContractId { get; set; }

    [SwaggerSchema("Installment number(s) being paid — comma-separated e.g. '1,2,3'")]
    public string InstallmentNos { get; set; } = string.Empty;

    [Required, Range(0.01, double.MaxValue), SwaggerSchema("Amount paid to owner")]
    public decimal Amount { get; set; }

    [Required, SwaggerSchema("Payment date")]
    public DateTime PaidDate { get; set; }

    [SwaggerSchema("Payment mode ID (from PaymentModes master)")]
    public int? PaymentModeId { get; set; }

    [SwaggerSchema("Payment mode name — Cash, Cheque, Bank Transfer etc.")]
    public string PaymentMode { get; set; } = "Cash";

    [SwaggerSchema("Cheque/reference number")]
    public string ChequeNumber { get; set; } = string.Empty;

    [SwaggerSchema("Reference number")]
    public string ReferenceNo { get; set; } = string.Empty;

    [SwaggerSchema("Fund Pool ID (money deducted from this pool)")]
    public int? FundPoolId { get; set; }

    [SwaggerSchema("Fund Pool name")]
    public string FundPoolName { get; set; } = string.Empty;

    [SwaggerSchema("Person who made the payment")]
    public string PaidBy { get; set; } = string.Empty;

    [SwaggerSchema("Additional notes")]
    public string Notes { get; set; } = string.Empty;

    /// <summary>Month-wise payment breakdown [{installmentNo, month, amount}]</summary>
    [SwaggerSchema("Per-month payment array — each entry has installmentNo, month, amount")]
    public List<OwnerMonthlyPaymentItem>? MonthlyPayments { get; set; }

    // Set by controller
    public int? AddedBy { get; set; }
}

/// <summary>Individual month payment in a transaction</summary>
public class OwnerMonthlyPaymentItem
{
    [SwaggerSchema("Installment number (1,2,3...)")]
    public int InstallmentNo { get; set; }

    [SwaggerSchema("Month label — e.g. 'January 2026'")]
    public string Month { get; set; } = string.Empty;

    [SwaggerSchema("Amount paid for this month")]
    public decimal Amount { get; set; }

    [SwaggerSchema("Due date of this installment (yyyy-MM-dd)")]
    public string? DueDate { get; set; }
}

/// <summary>Pay security deposit to owner</summary>
public class PayOwnerSecurityDepositRequest
{
    [Required]
    public int OwnerContractId { get; set; }

    [Required, Range(0.01, double.MaxValue)]
    public decimal Amount { get; set; }

    [Required]
    public DateTime PaidDate { get; set; }

    public string PaymentMode { get; set; } = "Cash";
    public int? PaymentModeId { get; set; }
    public string ChequeNumber { get; set; } = string.Empty;
    public int? FundPoolId { get; set; }
    public string FundPoolName { get; set; } = string.Empty;
    public string PaidBy { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
}

/// <summary>Settle/recover security deposit from owner</summary>
public class SettleOwnerSecurityDepositRequest
{
    [Required]
    public int OwnerContractId { get; set; }

    [SwaggerSchema("Amount recovered from owner (returned to fund pool)")]
    public decimal RecoverAmount { get; set; }

    [SwaggerSchema("Amount adjusted against owner dues")]
    public decimal AdjustAmount { get; set; }

    [SwaggerSchema("Amount forfeited/deducted from owner (penalty)")]
    public decimal ForfeitAmount { get; set; }

    public int? FundPoolId { get; set; }
    public string FundPoolName { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public string SettledBy { get; set; } = "Admin";
}

// ── Responses ─────────────────────────────────────────────────────────────────

/// <summary>Owner payment summary for a contract</summary>
public class OwnerPaymentSummaryResponse
{
    public int OwnerContractId { get; set; }
    public string OcCode { get; set; } = string.Empty;
    public int OwnerId { get; set; }
    public string OwnerName { get; set; } = string.Empty;
    public int CampId { get; set; }
    public string CampName { get; set; } = string.Empty;
    public string StartDate { get; set; } = string.Empty;
    public string? EndDate { get; set; }
    public decimal TotalPayable { get; set; }
    public decimal TotalPaidToOwner { get; set; }
    public decimal BalanceDueToOwner { get; set; }
    public decimal MonthlyRent { get; set; }
    public int NoOfMonths { get; set; }
    public int TotalInstallments { get; set; }
    public int PaidCount { get; set; }
    public int PendingCount { get; set; }
    public int PartialCount { get; set; }
    public decimal PaymentProgress { get; set; }
    public decimal SecurityDeposit { get; set; }
    public decimal SecurityDepositPaid { get; set; }
    public string PaymentType { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}

/// <summary>Single owner payment history row</summary>
public class OwnerPaymentHistoryResponse
{
    public int Id { get; set; }
    public string TxnCode { get; set; } = string.Empty;
    public int OwnerContractId { get; set; }
    public string OcCode { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Date { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string InstallmentNos { get; set; } = string.Empty;
    public string PaymentMode { get; set; } = string.Empty;
    public string ReferenceNo { get; set; } = string.Empty;
    public string PaidBy { get; set; } = string.Empty;
    public string FundPoolName { get; set; } = string.Empty;
    public int? ExpenseId { get; set; }
    public string Type { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

/// <summary>Owner security deposit status</summary>
public class OwnerSecurityDepositStatusResponse
{
    public int OwnerContractId { get; set; }
    public string OcCode { get; set; } = string.Empty;
    public string OwnerName { get; set; } = string.Empty;
    public string CampName { get; set; } = string.Empty;
    public decimal DepositAmount { get; set; }
    public decimal DepositPaid { get; set; }
    public decimal DepositPending { get; set; }
    public string Status { get; set; } = "Pending";
}

/// <summary>Owner payment voucher data</summary>
public class OwnerPaymentVoucherResponse
{
    public int TxnId { get; set; }
    public string TxnCode { get; set; } = string.Empty;
    public string OcCode { get; set; } = string.Empty;
    public string OwnerName { get; set; } = string.Empty;
    public string CampName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Date { get; set; } = string.Empty;
    public string PaymentMode { get; set; } = string.Empty;
    public string ReferenceNo { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string InstallmentNos { get; set; } = string.Empty;
    public string PaidBy { get; set; } = string.Empty;
    public string FundPoolName { get; set; } = string.Empty;
}

// ── Additional Requests ────────────────────────────────────────────────────────

/// <summary>Update (edit) an existing owner payment transaction</summary>
public class UpdateOwnerPaymentRequest
{
    [Required] public decimal Amount { get; set; }
    [Required] public DateTime PaidDate { get; set; }
    public int? PaymentModeId { get; set; }
    public string PaymentMode { get; set; } = "Cash";
    public string ChequeNumber { get; set; } = string.Empty;
    public string ReferenceNo { get; set; } = string.Empty;
    public int? FundPoolId { get; set; }
    public string FundPoolName { get; set; } = string.Empty;
    public string PaidBy { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public string InstallmentNos { get; set; } = string.Empty;
    /// <summary>Per-month payment array — same as PayOwnerRequest</summary>
    public List<OwnerMonthlyPaymentItem>? MonthlyPayments { get; set; }
    public int? UpdatedBy { get; set; }
}

/// <summary>Paginated list request for owner payments</summary>
public class OwnerPaymentListRequest : Common.PagedRequest
{
    public int?    OwnerId     { get; set; }
    public int?    CampId      { get; set; }
    public string? Status      { get; set; }
    public string? DateFrom    { get; set; }
    public string? DateTo      { get; set; }
    public string? SearchText  { get; set; }
}

// ── Additional Responses ──────────────────────────────────────────────────────

/// <summary>Owner contract list item for payment selection dropdown</summary>
public class OwnerContractListItemResponse
{
    public int     Id             { get; set; }
    public string  OcCode         { get; set; } = string.Empty;
    public int     OwnerId        { get; set; }
    public string  OwnerName      { get; set; } = string.Empty;
    public int     CampId         { get; set; }
    public string  CampName       { get; set; } = string.Empty;
    public string  PaymentType    { get; set; } = string.Empty;
    public decimal TotalAmount    { get; set; }
    public decimal PaidAmount     { get; set; }
    public decimal Balance        { get; set; }
    public decimal MonthlyRent    { get; set; }
    public int     NoOfMonths     { get; set; }
    public string  StartDate      { get; set; } = string.Empty;
    public string? EndDate        { get; set; }
    public decimal SecurityDeposit     { get; set; }
    public decimal SecurityDepositPaid { get; set; }
    public string  SecurityDepositStatus { get; set; } = "Pending";
    public string  Status         { get; set; } = string.Empty;
}

/// <summary>Single installment detail for Owner Payment modal</summary>
public class OwnerInstallmentDetailResponse
{
    public int     Id              { get; set; }
    public int     OwnerContractId { get; set; }
    public int     InstallmentNo   { get; set; }
    public decimal Amount          { get; set; }
    public decimal PaidAmount      { get; set; }
    public decimal Balance         { get; set; }
    public string  DueDate         { get; set; } = string.Empty;
    public string? PaidDate        { get; set; }
    public string  Status          { get; set; } = string.Empty;
    public string  PaymentMode     { get; set; } = string.Empty;
    public string  ReferenceNo     { get; set; } = string.Empty;
    public string  Month           { get; set; } = string.Empty;
    public string  MonthLabel      { get; set; } = string.Empty;
}

/// <summary>Month option for month filter in payment modal</summary>
public class OwnerInstallmentMonthResponse
{
    public string Month        { get; set; } = string.Empty;
    public string MonthLabel   { get; set; } = string.Empty;
    public string DueDate      { get; set; } = string.Empty;
    public int    InstallmentNo { get; set; }
    public bool   IsFullyPaid  { get; set; }
}

/// <summary>Ledger entry (DR/CR) for an owner contract</summary>
public class OwnerLedgerEntryResponse
{
    public string  Date          { get; set; } = string.Empty;
    public string  Description   { get; set; } = string.Empty;
    public string? InstallmentNos { get; set; }
    public decimal Dr            { get; set; }
    public decimal Cr            { get; set; }
    public decimal Balance       { get; set; }
    public string  Type          { get; set; } = string.Empty;
    public string  TxnCode       { get; set; } = string.Empty;
    public int?    TxnId         { get; set; }
}

/// <summary>Edit pre-fill data — payment + monthly breakdown</summary>
public class OwnerPaymentEditDataResponse
{
    // Transaction info
    public int      TxnId          { get; set; }
    public string   TxnCode        { get; set; } = string.Empty;
    public int      OwnerContractId { get; set; }
    public string   OcCode         { get; set; } = string.Empty;
    public decimal  Amount         { get; set; }
    public string   Date           { get; set; } = string.Empty;
    public string   PaymentMode    { get; set; } = string.Empty;
    public string   ReferenceNo    { get; set; } = string.Empty;
    public string   Description    { get; set; } = string.Empty;
    public string   InstallmentNos { get; set; } = string.Empty;
    public string   PaidBy         { get; set; } = string.Empty;
    public int?     ExpenseId      { get; set; }
    public int?     FundPoolId     { get; set; }
    public string   FundPoolName   { get; set; } = string.Empty;

    /// <summary>Monthly installments that were paid in this transaction</summary>
    public List<OwnerPaymentEditMonthItem> MonthlyPayments { get; set; } = new();
}

/// <summary>Single month paid in a transaction</summary>
public class OwnerPaymentEditMonthItem
{
    public int      Id             { get; set; }
    public int      InstallmentNo  { get; set; }
    public string   Month          { get; set; } = string.Empty;
    public string   DueDate        { get; set; } = string.Empty;
    public decimal  Amount         { get; set; }
    public decimal  PaidAmount     { get; set; }
    public decimal  Balance        { get; set; }
    public string   Status         { get; set; } = string.Empty;
}
