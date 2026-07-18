namespace TFMS_software_api.DTOs;

public class ReceiveSecurityDepositRequest
{
    public string   ContractId    { get; set; } = string.Empty;
    public decimal  Amount        { get; set; }
    public DateTime PaidDate      { get; set; }
    public string   PaymentMode   { get; set; } = "Cash";
    public int?     PaymentModeId { get; set; }
    public string   ChequeNumber  { get; set; } = string.Empty;
    public int?     FundPoolId    { get; set; }
    public string   FundPoolName  { get; set; } = string.Empty;
    public string   ReceivedBy    { get; set; } = string.Empty;
    public string   Notes         { get; set; } = string.Empty;
}

public class SecurityDepositStatusResponse
{
    public string   ContractId          { get; set; } = string.Empty;
    public string   TenantName          { get; set; } = string.Empty;
    public decimal  DepositAmount       { get; set; }
    public decimal  DepositPaid         { get; set; }
    public decimal  DepositBalance      { get; set; }
    public string   Status              { get; set; } = "Pending";
}

public class SettleSecurityDepositRequest
{
    public string   ContractId      { get; set; } = string.Empty;
    public decimal  AdjustAmount    { get; set; }  // Against rent dues
    public decimal  RefundAmount    { get; set; }  // Return to tenant
    public decimal  ForfeitAmount   { get; set; }  // Damage/penalty deduction
    public int?     FundPoolId      { get; set; }
    public string   FundPoolName    { get; set; } = string.Empty;
    public string   Notes           { get; set; } = string.Empty;
    public string   SettledBy       { get; set; } = "Admin";
}
