namespace TFMS_software_api.DTOs;

/// <summary>Financial summary for Make Payment page — GET /api/payments/summary/{contractId}</summary>
public class PaymentSummaryResponse
{
    public string   ContractId          { get; set; } = string.Empty;
    public int      TenantId            { get; set; }
    public string   TenantName          { get; set; } = string.Empty;
    public string   TenantContact       { get; set; } = string.Empty;
    public List<int> CampIds            { get; set; } = new();   // all camps (array)
    public int      CampId              { get; set; }             // primary camp
    public string   CampName            { get; set; } = string.Empty;
    public string   StartDate           { get; set; } = string.Empty;
    public string   EndDate             { get; set; } = string.Empty;
    public int      Months              { get; set; }
    public decimal  ContractTotal       { get; set; }
    public decimal  MonthlyTotal        { get; set; }
    public decimal  LessorAmount        { get; set; }
    public string   Status              { get; set; } = string.Empty;
    public int      TotalInstallments   { get; set; }
    public int      PaidCount           { get; set; }
    public int      PendingCount        { get; set; }
    public int      PartialCount        { get; set; }
    public decimal  TotalPaid           { get; set; }
    public decimal  TotalDue            { get; set; }
    public decimal  TotalScheduled      { get; set; }
    public decimal  NextInstallmentDue  { get; set; }
    public int?     NextInstallmentNo   { get; set; }
    public string   RoomNos             { get; set; } = string.Empty;
    public int      RoomCount           { get; set; }
    public decimal  CollectionPct       { get; set; } // TotalPaid / ContractTotal * 100
}

/// <summary>Single payment history row — GET /api/payments/history/{contractId}</summary>
public class PaymentHistoryResponse
{
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public int      InstallmentNo   { get; set; }
    public decimal  Amount          { get; set; }
    public string   DueDate         { get; set; } = string.Empty;
    public decimal  PaidAmount      { get; set; }
    public string?  PaidDate        { get; set; }
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
    public string   TenantName      { get; set; } = string.Empty;
    public string   CampName        { get; set; } = string.Empty;
}

/// <summary>Room info for Receive Payment — room-wise payment selection</summary>
public class ContractRoomPaymentInfo
{
    public int      Id            { get; set; }
    public string   ContractId    { get; set; } = string.Empty;
    public int      RoomId        { get; set; }
    public int      CampId        { get; set; }
    public string   RoomNo        { get; set; } = string.Empty;
    public string   CampName      { get; set; } = string.Empty;
    public decimal  MonthlyAmount { get; set; }
    public decimal  TotalAmount   { get; set; }
    public decimal  PaidAmount    { get; set; }
    public decimal  Balance       { get; set; }
}
