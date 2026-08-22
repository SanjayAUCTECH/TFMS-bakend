namespace TFMS_software_api.DTOs;

// ── Request ───────────────────────────────────────────────────────────────
/// <summary>
/// POST /api/AdvanceApproval
/// Approves all Advanced/AdvancedPartial installments for the selected month
/// and updates their PaidDate/TxnDate to the given PaymentDate.
/// </summary>
public class ApproveAdvancePaymentRequest
{
    /// <summary>New PaidDate applied to approved records. Required.</summary>
    public DateTime PaymentDate { get; set; }

    /// <summary>
    /// Target month in CRI.Month format — e.g. 'Jul26', 'Aug26'.
    /// Required.
    /// </summary>
    public string Month { get; set; } = string.Empty;

    /// <summary>Optional: approve only for this contract.</summary>
    public string? ContractId { get; set; }

    /// <summary>Optional: approve only for this camp.</summary>
    public int? CampId { get; set; }

    /// <summary>Optional: approve only for this room.</summary>
    public int? RoomId { get; set; }
}

// ── Per-row result ────────────────────────────────────────────────────────
public class ApprovedInstallmentRow
{
    public int      CriId          { get; set; }
    public string   ContractId     { get; set; } = string.Empty;
    public int      CampId         { get; set; }
    public string   CampName       { get; set; } = string.Empty;
    public int      RoomId         { get; set; }
    public string   RoomNo         { get; set; } = string.Empty;
    public int      InstallmentNo  { get; set; }
    public string   Month          { get; set; } = string.Empty;
    public decimal  InstallAmount  { get; set; }
    public decimal  PaidAmount     { get; set; }
    public string   NewStatus      { get; set; } = string.Empty;   // Paid | PaidPartial
    public DateTime NewPaidDate    { get; set; }
}

// ── Response ──────────────────────────────────────────────────────────────
public class ApproveAdvancePaymentResponse
{
    public int    UpdatedCount { get; set; }   // total CRI rows updated
    public string Month        { get; set; } = string.Empty;
    public string PaymentDate  { get; set; } = string.Empty;
    public List<ApprovedInstallmentRow> UpdatedRows { get; set; } = new();
}
