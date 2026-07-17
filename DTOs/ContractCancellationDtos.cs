namespace TFMS_software_api.DTOs;

public class CancelContractRequest
{
    public string?  ContractId         { get; set; }
    public string?  CancellationDate   { get; set; }
    public string?  CancellationReason { get; set; }
    public decimal? RefundAmount       { get; set; } = 0;
    public decimal? PenaltyAmount      { get; set; } = 0;
    public decimal? SettlementAmount   { get; set; } = 0;
    public string?  CancelledBy        { get; set; }
    public string?  Notes              { get; set; }
}

public class ContractCancellationResponse
{
    public int      Id                 { get; set; }
    public string   ContractId         { get; set; } = string.Empty;
    public int      TenantId           { get; set; }
    public string?  TenantName         { get; set; }
    public string?  CancellationDate   { get; set; }
    public string?  CancellationReason { get; set; }
    public decimal  RefundAmount       { get; set; }
    public decimal  PenaltyAmount      { get; set; }
    public decimal  SettlementAmount   { get; set; }
    public string?  CancelledBy        { get; set; }
    public string?  Notes              { get; set; }
    public string   Status             { get; set; } = string.Empty;
    public DateTime CreatedAt          { get; set; }
    public DateTime UpdatedAt          { get; set; }
}
