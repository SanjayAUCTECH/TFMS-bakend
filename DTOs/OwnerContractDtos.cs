using System.ComponentModel.DataAnnotations;
using Swashbuckle.AspNetCore.Annotations;

namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────────────────────
/// <summary>Owner Contract create karne ka request payload</summary>
public class CreateOwnerContractRequest
{
    [Required, SwaggerSchema("Camp ID (required)")]
    public int     CampId      { get; set; }

    [Required, SwaggerSchema("Owner ID (required)")]
    public int     OwnerId     { get; set; }

    [Required, SwaggerSchema("Payment type: 'monthly', 'quarterly', 'yearly', 'lumpsum'")]
    public string  PaymentType { get; set; } = "monthly";

    [Required, SwaggerSchema("Total contract amount")]
    public decimal TotalAmount { get; set; }

    [Required, SwaggerSchema("Contract start date (yyyy-MM-dd)")]
    public string  StartDate   { get; set; } = string.Empty;

    [SwaggerSchema("Contract end date (yyyy-MM-dd) — optional")]
    public string? EndDate     { get; set; }

    [SwaggerSchema("Actual contract/agreement date (yyyy-MM-dd) — optional")]
    public string? ContractDate { get; set; }

    [SwaggerSchema("Monthly rent amount")]
    public decimal MonthlyRent { get; set; } = 0;

    [SwaggerSchema("Number of months for the contract")]
    public int NoOfMonths { get; set; } = 0;

    [SwaggerSchema("Security deposit amount")]
    public decimal SecurityDeposit { get; set; } = 0;

    [SwaggerSchema("Security deposit paid amount")]
    public decimal SecurityDepositPaid { get; set; } = 0;

    [SwaggerSchema("Security deposit paid date (yyyy-MM-dd) — optional")]
    public string? SecurityDepositPaidDate { get; set; }

    [Required, SwaggerSchema("Installments list (at least one required)")]
    public List<InstallmentRequest> Installments { get; set; } = new();

    [SwaggerSchema("Monthly installments list — optional")]
    public List<MonthlyContractInstallmentRequest> MonthlyInstallments { get; set; } = new();
}

/// <summary>Owner Contract update karne ka request payload</summary>
public class UpdateOwnerContractRequest
{
    [SwaggerSchema("Camp ID — change karna ho toh bhejo, nahi toh null")]
    public int?     CampId                  { get; set; }

    [SwaggerSchema("Owner ID — change karna ho toh bhejo, nahi toh null")]
    public int?     OwnerId                 { get; set; }

    [SwaggerSchema("Payment type: monthly, quarterly, yearly, lumpsum")]
    public string?  PaymentType             { get; set; }

    [SwaggerSchema("Total contract amount")]
    public decimal? TotalAmount             { get; set; }

    [SwaggerSchema("Contract start date (yyyy-MM-dd)")]
    public string?  StartDate               { get; set; }

    [SwaggerSchema("Contract end date (yyyy-MM-dd)")]
    public string?  EndDate                 { get; set; }

    [SwaggerSchema("Actual contract/agreement date (yyyy-MM-dd)")]
    public string?  ContractDate            { get; set; }

    [SwaggerSchema("Monthly rent amount")]
    public decimal? MonthlyRent             { get; set; }

    [SwaggerSchema("Number of months")]
    public int?     NoOfMonths              { get; set; }

    [SwaggerSchema("Security deposit amount")]
    public decimal? SecurityDeposit         { get; set; }

    [SwaggerSchema("Security deposit paid amount")]
    public decimal? SecurityDepositPaid     { get; set; }

    [SwaggerSchema("Security deposit paid date (yyyy-MM-dd)")]
    public string?  SecurityDepositPaidDate { get; set; }

    [SwaggerSchema("Status: Active, Expired, Cancelled")]
    public string?  Status                  { get; set; }

    [SwaggerSchema("Installments — null bhejo toh purane rahenge, array bhejo toh replace ho jayenge")]
    public List<InstallmentRequest>? Installments { get; set; }

    [SwaggerSchema("Monthly installments — null bhejo toh purane rahenge, array bhejo toh replace ho jayenge")]
    public List<MonthlyContractInstallmentRequest>? MonthlyInstallments { get; set; }
}

/// <summary>Single installment item</summary>
public class InstallmentRequest
{
    [SwaggerSchema("Installment number (1, 2, 3...)")]
    public int     No          { get; set; }

    [SwaggerSchema("Installment amount")]
    public decimal Amount      { get; set; }

    [SwaggerSchema("Due date (yyyy-MM-dd)")]
    public string  DueDate     { get; set; } = string.Empty;

    [SwaggerSchema("Payment mode — e.g. Cash, Cheque, Bank Transfer")]
    public string? PaymentMode { get; set; }

    [SwaggerSchema("Reference/cheque number")]
    public string? ReferenceNo { get; set; }

    [SwaggerSchema("Month label — e.g. 'January 2026'")]
    public string? Month       { get; set; }
}

public class MonthlyContractInstallmentRequest
{
    public int      InstallmentNo { get; set; }
    public decimal  Amount        { get; set; }
    public decimal  PaidAmount    { get; set; }
    public decimal  Balance       { get; set; }
    public string   DueDate       { get; set; } = string.Empty;
    public string?  PaidDate      { get; set; }
    public string   Status        { get; set; } = "Pending";
    public int?     ExpenseId     { get; set; }
    public string   PaymentMode   { get; set; } = string.Empty;
    public string   PaymentStatus { get; set; } = "Pending";
    public string   ReferenceNo   { get; set; } = string.Empty;
    public string   Month         { get; set; } = string.Empty;
}

// ── Response ──────────────────────────────────────────────────────────────────
public class OwnerContractResponse
{
    public int      Id                       { get; set; }
    public string   OcCode                   { get; set; } = string.Empty;
    public int      CampId                   { get; set; }
    public string   CampName                 { get; set; } = string.Empty;
    public int      OwnerId                  { get; set; }
    public string   OwnerName                { get; set; } = string.Empty;
    public string   OwnerCode                { get; set; } = string.Empty;
    public string   PaymentType              { get; set; } = string.Empty;
    public decimal  TotalAmount              { get; set; }
    public decimal  PaidAmount               { get; set; }
    public decimal  Balance                  { get; set; }
    public string   StartDate                { get; set; } = string.Empty;
    public string?  EndDate                  { get; set; }
    public decimal  SecurityDeposit          { get; set; }
    public decimal  SecurityDepositPaid      { get; set; }
    public string?  SecurityDepositPaidDate  { get; set; }
    public string?  ContractDate             { get; set; }
    public decimal  MonthlyRent              { get; set; }
    public int      NoOfMonths               { get; set; }
    public string   Status                   { get; set; } = string.Empty;
    public bool     IsRenewal                { get; set; }
    public DateTime CreatedAt                { get; set; }
    public List<OwnerInstallmentResponse>  Installments { get; set; } = new();
    public List<OwnerTransactionResponse>  Transactions { get; set; } = new();
    public List<OwnerMonthlyContractInstallmentResponse> MonthlyInstallments { get; set; } = new();
}

public class OwnerInstallmentResponse
{
    public int      Id              { get; set; }
    public int      OwnerContractId { get; set; }
    public int      No              { get; set; }
    public decimal  Amount          { get; set; }
    public decimal  PaidAmount      { get; set; }
    public string   DueDate         { get; set; } = string.Empty;
    public string?  PaidDate        { get; set; }
    public string   Status          { get; set; } = string.Empty;
    public int?     ExpenseId       { get; set; }
    public string   PaymentMode     { get; set; } = string.Empty;
    public string   ReferenceNo     { get; set; } = string.Empty;
    public string   Remarks         { get; set; } = string.Empty;
    public string   Month           { get; set; } = string.Empty;
}

public class OwnerTransactionResponse
{
    public int      Id              { get; set; }
    public string   TxnCode         { get; set; } = string.Empty;
    public int      OwnerContractId { get; set; }
    public string   OcCode          { get; set; } = string.Empty;
    public int      CampId          { get; set; }
    public string   CampName        { get; set; } = string.Empty;
    public int      OwnerId         { get; set; }
    public string   OwnerName       { get; set; } = string.Empty;
    public string   Type            { get; set; } = string.Empty;
    public decimal  Amount          { get; set; }
    public string   Date            { get; set; } = string.Empty;
    public string   Description     { get; set; } = string.Empty;
    public string   InstallmentNos  { get; set; } = string.Empty;
    public int?     ExpenseId       { get; set; }
    public string   ReferenceNo     { get; set; } = string.Empty;
    public string   PaymentMode     { get; set; } = string.Empty;
    public DateTime CreatedAt       { get; set; }
}

public class OwnerMonthlyContractInstallmentResponse
{
    public int      Id                           { get; set; }
    public string   MonthlyContractInstallmentId { get; set; } = string.Empty;
    public int      OwnerContractId              { get; set; }
    public int      OwnerId                      { get; set; }
    public int      CampId                       { get; set; }
    public int      InstallmentNo                { get; set; }
    public decimal  Amount                       { get; set; }
    public decimal  PaidAmount                   { get; set; }
    public decimal  Balance                      { get; set; }
    public string   DueDate                      { get; set; } = string.Empty;
    public string?  PaidDate                     { get; set; }
    public string   Status                       { get; set; } = string.Empty;
    public int?     ExpenseId                    { get; set; }
    public string   PaymentMode                  { get; set; } = string.Empty;
    public string   PaymentStatus                { get; set; } = string.Empty;
    public string   ReferenceNo                  { get; set; } = string.Empty;
    public string   Month                        { get; set; } = string.Empty;
    public DateTime CreatedAt                    { get; set; }
    public DateTime UpdatedAt                    { get; set; }
}
