namespace TFMS_software_api.Models;

public class OwnerContract
{
    public int      Id          { get; set; }
    public string   OcCode      { get; set; } = string.Empty;
    public int      CampId      { get; set; }
    public string   CampName    { get; set; } = string.Empty;
    public int      OwnerId     { get; set; }
    public string   OwnerName   { get; set; } = string.Empty;
    public string   OwnerCode   { get; set; } = string.Empty;
    public string   PaymentType { get; set; } = string.Empty;
    public decimal  TotalAmount { get; set; }
    public decimal  PaidAmount  { get; set; }
    public decimal  Balance     { get; set; }
    public DateTime StartDate   { get; set; }
    public string   Status      { get; set; } = "Active";
    public DateTime CreatedAt   { get; set; }
    public DateTime UpdatedAt   { get; set; }
    public List<OwnerInstallment>  Installments  { get; set; } = new();
    public List<OwnerTransaction>  Transactions  { get; set; } = new();
}

public class OwnerInstallment
{
    public int      Id              { get; set; }
    public int      OwnerContractId { get; set; }
    public int      No              { get; set; }
    public decimal  Amount          { get; set; }
    public decimal  PaidAmount      { get; set; }
    public DateTime DueDate         { get; set; }
    public DateTime? PaidDate       { get; set; }
    public string   Status          { get; set; } = "Pending";
    public int?     ExpenseId       { get; set; }
}

public class OwnerTransaction
{
    public int      Id              { get; set; }
    public string   TxnCode         { get; set; } = string.Empty;
    public int      OwnerContractId { get; set; }
    public string   OcCode          { get; set; } = string.Empty;
    public int      CampId          { get; set; }
    public string   CampName        { get; set; } = string.Empty;
    public int      OwnerId         { get; set; }
    public string   OwnerName       { get; set; } = string.Empty;
    public string   Type            { get; set; } = string.Empty;   // DR | CR
    public decimal  Amount          { get; set; }
    public DateTime Date            { get; set; }
    public string   Description     { get; set; } = string.Empty;
    public string   InstallmentNos  { get; set; } = string.Empty;
    public int?     ExpenseId       { get; set; }
    public DateTime CreatedAt       { get; set; }
}
