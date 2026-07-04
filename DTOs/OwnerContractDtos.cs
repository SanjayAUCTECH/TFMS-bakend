using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────────────────────
public class CreateOwnerContractRequest
{
    [Required] public int     CampId      { get; set; }
    [Required] public int     OwnerId     { get; set; }
    [Required] public string  PaymentType { get; set; } = "monthly";
    [Required] public decimal TotalAmount { get; set; }
    [Required] public string  StartDate   { get; set; } = string.Empty;
    [Required] public List<InstallmentRequest> Installments { get; set; } = new();
}

public class InstallmentRequest
{
    public int     No      { get; set; }
    public decimal Amount  { get; set; }
    public string  DueDate { get; set; } = string.Empty;
}

// ── Response ──────────────────────────────────────────────────────────────────
public class OwnerContractResponse
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
    public string   StartDate   { get; set; } = string.Empty;
    public string   Status      { get; set; } = string.Empty;
    public DateTime CreatedAt   { get; set; }
    public List<OwnerInstallmentResponse> Installments { get; set; } = new();
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
}
