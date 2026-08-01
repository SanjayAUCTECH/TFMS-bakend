using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────────────────────
public class CreateOwnerContractRequest
{
    [Required] public int     CampId                   { get; set; }
    [Required] public int     OwnerId                  { get; set; }
    [Required] public string  PaymentType              { get; set; } = "monthly";
    [Required] public decimal TotalAmount              { get; set; }
    [Required] public string  StartDate                { get; set; } = string.Empty;
    public string?  EndDate                  { get; set; }
    public decimal  SecurityDeposit          { get; set; } = 0;
    public decimal  SecurityDepositPaid      { get; set; } = 0;
    public string?  SecurityDepositPaidDate  { get; set; }
    [Required] public List<InstallmentRequest> Installments { get; set; } = new();
    public List<MonthlyContractInstallmentRequest> MonthlyInstallments { get; set; } = new();
}

public class InstallmentRequest
{
    public int     No          { get; set; }
    public decimal Amount      { get; set; }
    public string  DueDate     { get; set; } = string.Empty;
    public string? PaymentMode { get; set; }
    public string? ReferenceNo { get; set; }
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
    public string   Status                   { get; set; } = string.Empty;
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
