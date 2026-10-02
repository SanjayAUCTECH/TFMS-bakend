namespace TFMS_software_api.DTOs;

/// <summary>
/// Bulk payment import request from Excel
/// Handles both Rent and Security Deposit payments
/// </summary>
public class BulkPaymentImportRequest
{
    public List<BulkPaymentItem> Payments { get; set; } = new();
}

/// <summary>
/// Single payment item from Excel
/// </summary>
public class BulkPaymentItem
{
    public string   ContractId      { get; set; } = string.Empty;
    public string   PaymentType     { get; set; } = "Rent";  // "Rent" or "Security Deposit"
    public string   CampName                { get; set; } = string.Empty;
    public string   RoomNo                  { get; set; } = string.Empty;
    public string   Month                   { get; set; } = string.Empty;  // "Sep 2026" for Rent, optional for SD
    public int?     RoomInstallmentNo       { get; set; }                  // Room-wise installment (ContractRoomInstallments)
    public int?     ContractInstallmentNo   { get; set; }                  // Contract-level installment (0 or 1 for auto-manage)
    public string   Status                  { get; set; } = "Paid";        // Paid/Partial/Advanced/Received
    public decimal  Amount          { get; set; }
    public DateTime PaymentDate     { get; set; }
    public string   PaymentMode     { get; set; } = "Cash";
    public string   FundPool        { get; set; } = string.Empty;
    public string   ChequeNumber    { get; set; } = string.Empty;
    public string   ClearanceDate   { get; set; } = string.Empty;
    public string   IssuedBy        { get; set; } = string.Empty;
    public string   ReceivedBy      { get; set; } = string.Empty;
    public string   ContactNumber   { get; set; } = string.Empty;
    public string   Description     { get; set; } = string.Empty;
}

/// <summary>
/// Response for bulk payment import
/// </summary>
public class BulkPaymentImportResponse
{
    public int TotalRecords      { get; set; }
    public int SuccessCount      { get; set; }
    public int FailureCount      { get; set; }
    public List<BulkPaymentResult> Results { get; set; } = new();
}

/// <summary>
/// Individual payment processing result
/// </summary>
public class BulkPaymentResult
{
    public int     RowNumber        { get; set; }
    public string  ContractId       { get; set; } = string.Empty;
    public string  PaymentType      { get; set; } = string.Empty;
    public string  CampName         { get; set; } = string.Empty;
    public string  RoomNo           { get; set; } = string.Empty;
    public decimal Amount           { get; set; }
    public bool    Success          { get; set; }
    public string  Message          { get; set; } = string.Empty;
    public string  ErrorDetails     { get; set; } = string.Empty;
    public int?    TxnRecordId      { get; set; }  // Created TxnRecord ID if successful
}

/// <summary>
/// Validation result for bulk payment item
/// </summary>
public class BulkPaymentValidation
{
    public bool   IsValid        { get; set; }
    public string ErrorMessage   { get; set; } = string.Empty;
    public int?   RoomId         { get; set; }
    public int?   CampId         { get; set; }
    public int?   FundPoolId     { get; set; }
    public int?   PaymentModeId  { get; set; }
    public int?   InstallmentNo  { get; set; }
    public int?   ContractRoomInstallmentId { get; set; }
}
