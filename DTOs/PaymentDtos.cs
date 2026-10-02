using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class RecordPaymentRequest
{
    [Required] public string   ContractId      { get; set; } = string.Empty;
    public int      InstallmentNo   { get; set; } = 0;
    [Range(0.01, double.MaxValue)] public decimal PaidAmount { get; set; }
    [Required] public DateTime PaidDate         { get; set; }
    public int?     PaymentModeId   { get; set; }
    public string   PaymentMode     { get; set; } = string.Empty;
    public string   ChequeNumber    { get; set; } = string.Empty;
    public string   ClearanceDate   { get; set; } = string.Empty;
    public string   Description     { get; set; } = string.Empty;
    public string   ReceivedBy      { get; set; } = string.Empty;
    public string   ReceivedContact { get; set; } = string.Empty;
    public int?     FundPoolId      { get; set; }
    public string   FundPoolName    { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    public int?     AddedBy         { get; set; }
    /// <summary>Room-wise payment breakdown [{roomId, campId, amount}]</summary>
    public List<RoomPaymentItem>? RoomPayments { get; set; }
}

/// <summary>Individual room payment in a transaction</summary>
public class RoomPaymentItem
{
    public int      RoomId                    { get; set; }
    public int      CampId                    { get; set; }
    public decimal  Amount                    { get; set; }
    public int?     ContractRoomInstallmentId { get; set; }
    public int?     InstallmentNo             { get; set; }
    public string   Month                     { get; set; } = string.Empty;
    public string?  DueDate                   { get; set; }
    public string?  Status                    { get; set; }  // Status from API (Paid/Partial/Pending)
}

public class PaymentListRequest : Common.PagedRequest
{
    public string? ContractId    { get; set; }
    public int?    TenantId      { get; set; }
    public int?    CampId        { get; set; }
    public string? Month         { get; set; }
    public string? Year          { get; set; }
    public string? PaymentStatus { get; set; }
    public int?    PaymentModeId { get; set; }
    public string? DateFrom      { get; set; }
    public string? DateTo        { get; set; }
}

public class PaymentResponse
{
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public string   TenantName      { get; set; } = string.Empty;
    public string   TenantCode      { get; set; } = string.Empty;
    public string   RoomNo          { get; set; } = string.Empty;
    public string   CampName        { get; set; } = string.Empty;
    public string   FloorName       { get; set; } = string.Empty;
    public int      InstallmentNo   { get; set; }
    public decimal  Amount          { get; set; }
    public DateTime DueDate         { get; set; }
    public decimal  PaidAmount      { get; set; }
    public decimal  BalanceAmount   { get; set; }
    public DateTime? PaidDate       { get; set; }
    public string   Status          { get; set; } = string.Empty;
    public string   PaymentMode     { get; set; } = string.Empty;
    public int?     PaymentModeId   { get; set; }
    public string   ChequeNumber    { get; set; } = string.Empty;
    public string   ClearanceDate   { get; set; } = string.Empty;
    public string   Description     { get; set; } = string.Empty;
    public string   ReceivedBy      { get; set; } = string.Empty;
    public string   ReceivedContact { get; set; } = string.Empty;
    public int?     FundPoolId      { get; set; }
    public string   FundPoolName    { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    public string   DueMonth        { get; set; } = string.Empty;
    public int      DueYear         { get; set; }
}

// ============================================
// Filtered Payment Data DTOs
// ============================================

/// <summary>Request for filtered payment data from ContractRoomInstallments</summary>
public class FilteredPaymentDataRequest : Common.PagedRequest
{
    public string? Month         { get; set; }  // Month filter (e.g., "Oct2026")
    public int?    CampId        { get; set; }  // Camp filter
    public int?    RoomId        { get; set; }  // Room filter
    public string? Status        { get; set; }  // Payment status (Paid/Pending/Partial)
    public string? ContractId    { get; set; }  // Contract ID filter
    public int?    TenantId      { get; set; }  // Tenant filter
}

/// <summary>Complete payment data with contract details</summary>
public class FilteredPaymentDataResponse
{
    // ContractRoomInstallments Data
    public int      Id                      { get; set; }
    public string   ContractId              { get; set; } = string.Empty;
    public int      RoomId                  { get; set; }
    public int      CampId                  { get; set; }
    public int      InstallmentNo           { get; set; }
    public decimal  InstallAmount           { get; set; }
    public DateTime DueDate                 { get; set; }
    public string   Month                   { get; set; } = string.Empty;
    public string   PaymentMode             { get; set; } = string.Empty;
    public string   ReferenceNo             { get; set; } = string.Empty;
    public DateTime? ClearanceDate          { get; set; }
    public string   Status                  { get; set; } = string.Empty;
    public decimal  PaidAmount              { get; set; }
    public decimal  Balance                 { get; set; }
    public DateTime? PaidDate               { get; set; }
    
    // Room Details
    public string   RoomNo                  { get; set; } = string.Empty;
    public string   FloorName               { get; set; } = string.Empty;
    
    // Camp Details
    public string   CampName                { get; set; } = string.Empty;
    public string   CampLocation            { get; set; } = string.Empty;
    
    // Contract Details
    public DateTime ContractStartDate       { get; set; }
    public DateTime ContractEndDate         { get; set; }
    public string   ContractStatus          { get; set; } = string.Empty;
    public int      ContractMonths          { get; set; }
    public decimal  ContractTotal           { get; set; }
    public decimal  MonthlyTotal            { get; set; }
    
    // Tenant Details
    public int      TenantId                { get; set; }
    public string   TenantName              { get; set; } = string.Empty;
    public string   TenantCode              { get; set; } = string.Empty;
    public string   TenantContact           { get; set; } = string.Empty;
    public string   TenantEmail             { get; set; } = string.Empty;
    
    // ContractInstallments Summary
    public decimal  TotalDueAmount          { get; set; }
    public decimal  TotalPaidAmount         { get; set; }
    public decimal  TotalBalance            { get; set; }
    
    // Security Deposit Details
    public decimal  SecurityDepositAmount   { get; set; }  // Total SD for this contract
    public decimal  SecurityDepositPaid     { get; set; }  // SD paid amount
    public decimal  SecurityDepositBalance  { get; set; }  // SD balance (Amount - Paid)
    public string   SecurityDepositStatus   { get; set; } = string.Empty; // Received/Partial/Pending
    
    // Calculated Fields
    public int      DaysOverdue             { get; set; }
    public bool     IsOverdue               { get; set; }
}
