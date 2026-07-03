namespace TFMS_software_api.Models;

public class Payment
{
    public int      Id              { get; set; }
    public string   ContractId      { get; set; } = string.Empty;
    public int      InstallmentNo   { get; set; }
    public decimal  Amount          { get; set; }
    public DateTime DueDate         { get; set; }
    public decimal  PaidAmount      { get; set; }
    public DateTime? PaidDate       { get; set; }
    public string   Status          { get; set; } = "Pending";   // Pending | Paid | Partial | Overdue
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
}
