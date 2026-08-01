using Swashbuckle.AspNetCore.Annotations;
using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

/// <summary>Owner Contract Renewal request</summary>
public class RenewOwnerContractRequest
{
    // Set by controller from route — frontend ko nahi bhejna
    public int OriginalOwnerContractId { get; set; }

    [Required, SwaggerSchema("New contract start date (yyyy-MM-dd)")]
    public string StartDate { get; set; } = string.Empty;

    [SwaggerSchema("New contract end date (yyyy-MM-dd) — optional")]
    public string? EndDate { get; set; }

    [SwaggerSchema("Actual contract/agreement date (yyyy-MM-dd) — optional")]
    public string? ContractDate { get; set; }

    [Required, SwaggerSchema("Total amount of new contract")]
    public decimal TotalAmount { get; set; }

    [SwaggerSchema("Monthly rent amount")]
    public decimal MonthlyRent { get; set; } = 0;

    [SwaggerSchema("Number of months for the renewal contract")]
    public int NoOfMonths { get; set; } = 0;

    [Required, SwaggerSchema("Payment type: monthly, quarterly, yearly, lumpsum")]
    public string PaymentType { get; set; } = "monthly";

    [SwaggerSchema("Security deposit amount")]
    public decimal SecurityDeposit { get; set; } = 0;

    [SwaggerSchema("Security deposit paid amount")]
    public decimal SecurityDepositPaid { get; set; } = 0;

    [SwaggerSchema("Security deposit paid date (yyyy-MM-dd) — optional")]
    public string? SecurityDepositPaidDate { get; set; }

    [SwaggerSchema("true = purana contract Expired ho jayega, false = Active rahega")]
    public bool ExpireOldContract { get; set; } = true;

    [SwaggerSchema("Renewal notes/remarks — optional")]
    public string? Notes { get; set; }

    /// <summary>
    /// Installments list — same as create contract.
    /// Example:
    /// [
    ///   { "no": 1, "amount": 15000, "dueDate": "2027-01-01", "paymentMode": "Cheque", "referenceNo": "CHQ-001", "month": "January 2027" },
    ///   { "no": 2, "amount": 15000, "dueDate": "2027-04-01", "paymentMode": "Cash",   "referenceNo": "",        "month": "April 2027"   }
    /// ]
    /// </summary>
    [Required, SwaggerSchema("Installments list — same as create contract (at least one required)")]
    public List<InstallmentRequest> Installments { get; set; } = new();

    /// <summary>
    /// Monthly installments array — same as create contract.
    /// Har month ki detail:
    /// [
    ///   {
    ///     "installmentNo": 1,
    ///     "amount": 5000,
    ///     "paidAmount": 0,
    ///     "balance": 5000,
    ///     "dueDate": "2027-01-01",
    ///     "paidDate": null,
    ///     "status": "Pending",
    ///     "paymentMode": "",
    ///     "paymentStatus": "Pending",
    ///     "referenceNo": "",
    ///     "month": "January 2027"
    ///   }
    /// ]
    /// </summary>
    [SwaggerSchema("Monthly installments — same format as create contract (optional, but recommended for monthly payment type)")]
    public List<MonthlyContractInstallmentRequest> MonthlyInstallments { get; set; } = new();
}

/// <summary>Owner Contract Renewal response</summary>
public class OwnerContractRenewalResponse
{
    public int      Id                        { get; set; }
    public string   RenewalCode               { get; set; } = string.Empty;
    public int      OriginalOwnerContractId   { get; set; }
    public string   OriginalOcCode            { get; set; } = string.Empty;
    public int      NewOwnerContractId        { get; set; }
    public string   NewOcCode                 { get; set; } = string.Empty;
    public int      CampId                    { get; set; }
    public string   CampName                  { get; set; } = string.Empty;
    public int      OwnerId                   { get; set; }
    public string   OwnerName                 { get; set; } = string.Empty;
    public decimal  TotalAmount               { get; set; }
    public decimal  MonthlyRent               { get; set; }
    public int      NoOfMonths                { get; set; }
    public string   StartDate                 { get; set; } = string.Empty;
    public string?  EndDate                   { get; set; }
    public string?  ContractDate              { get; set; }
    public bool     ExpireOldContract         { get; set; }
    public string?  Notes                     { get; set; }
    public string   Status                    { get; set; } = string.Empty;
    public DateTime CreatedAt                 { get; set; }
    public OwnerContractResponse? NewContract { get; set; }
}
