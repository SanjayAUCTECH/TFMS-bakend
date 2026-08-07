using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

// ── CREATE REQUEST (Parent + Array of Heads) ─────────────────
public class CreateAccountMasterRequest
{
    public DateTime TransDate      { get; set; }
    public string   Mode           { get; set; } = string.Empty;
    public string   VoucherNo      { get; set; } = string.Empty;  // Optional — if empty, auto-generate
    public int?     FundPoolId     { get; set; }
    public string   FundPoolName   { get; set; } = string.Empty;
    public string   Nature         { get; set; } = string.Empty;   // HO | Camp
    public int?     CampId         { get; set; }
    public string   CampName       { get; set; } = string.Empty;
    public string   RecipientRole  { get; set; } = string.Empty;
    public int?     RecipientId    { get; set; }
    public string   RecipientName  { get; set; } = string.Empty;
    public string   Purpose        { get; set; } = string.Empty;

    /// <summary>Array of head items — each item goes to Income or Expense table based on PaymentType</summary>
    public List<AccountMasterHeadItem> Heads { get; set; } = new();
}

public class AccountMasterHeadItem
{
    /// <summary>Income or Expense</summary>
    public string   PaymentType    { get; set; } = string.Empty;
    public string   Head           { get; set; } = string.Empty;
    public decimal  Amount         { get; set; }
    public string   Purpose        { get; set; } = string.Empty;
}

// ── UPDATE REQUEST ───────────────────────────────────────────
public class UpdateAccountMasterRequest
{
    public DateTime TransDate      { get; set; }
    public string   Mode           { get; set; } = string.Empty;
    public int?     FundPoolId     { get; set; }
    public string   FundPoolName   { get; set; } = string.Empty;
    public string   Nature         { get; set; } = string.Empty;
    public int?     CampId         { get; set; }
    public string   CampName       { get; set; } = string.Empty;
    public string   RecipientRole  { get; set; } = string.Empty;
    public int?     RecipientId    { get; set; }
    public string   RecipientName  { get; set; } = string.Empty;
    public string   Purpose        { get; set; } = string.Empty;

    public List<AccountMasterHeadItem> Heads { get; set; } = new();
}

// ── LIST REQUEST ─────────────────────────────────────────────
public class AccountMasterListRequest : PagedRequest
{
    public string? DateFrom      { get; set; }
    public string? DateTo        { get; set; }
    public string? PaymentType   { get; set; }   // Income | Expense | null=All
    public string? Nature        { get; set; }   // Camp | HO | SD | null=All
    public int?    RecipientId   { get; set; }   // Filter by assigned person/recipient
}

// ── RESPONSE ─────────────────────────────────────────────────
public class AccountMasterResponse
{
    public int      Id            { get; set; }
    public string   AccountId     { get; set; } = string.Empty;
    public string   VoucherNo     { get; set; } = string.Empty;
    public DateTime TransDate     { get; set; }
    public string   PaymentType   { get; set; } = string.Empty;
    public string   Mode          { get; set; } = string.Empty;
    public string   FundPool      { get; set; } = string.Empty;
    public string   FundPoolName  { get; set; } = string.Empty;
    public decimal  Amount        { get; set; }
    public string   Nature        { get; set; } = string.Empty;
    public string   RecipientRole { get; set; } = string.Empty;
    public string   RecipientName { get; set; } = string.Empty;
    public string   Purpose       { get; set; } = string.Empty;
    public int?     RecipientId   { get; set; }
    public DateTime CreatedAt     { get; set; }
    public DateTime UpdatedAt     { get; set; }
}

public class AccountMasterDetailResponse
{
    public int      Id            { get; set; }
    public string   AccountId     { get; set; } = string.Empty;
    public string   VoucherNo     { get; set; } = string.Empty;
    public DateTime TransDate     { get; set; }
    public string   PaymentType   { get; set; } = string.Empty;
    public string   Mode          { get; set; } = string.Empty;
    public string   FundPool      { get; set; } = string.Empty;
    public string   FundPoolName  { get; set; } = string.Empty;
    public decimal  Amount        { get; set; }
    public string   Nature        { get; set; } = string.Empty;
    public int?     CampId        { get; set; }
    public string   CampName      { get; set; } = string.Empty;
    public string   RecipientRole { get; set; } = string.Empty;
    public string   RecipientName { get; set; } = string.Empty;
    public string   Purpose       { get; set; } = string.Empty;
    public int?     RecipientId   { get; set; }
    public DateTime CreatedAt     { get; set; }
    public DateTime UpdatedAt     { get; set; }
    public List<AccountMasterHeadResponse> Heads { get; set; } = new();
}

public class AccountMasterHeadResponse
{
    public int      Id            { get; set; }
    public string   PaymentType   { get; set; } = string.Empty;
    public string   Head          { get; set; } = string.Empty;
    public decimal  Amount        { get; set; }
    public string   Purpose       { get; set; } = string.Empty;
    public string   RefId         { get; set; } = string.Empty;  // IncomeId or ExpenseId
}
