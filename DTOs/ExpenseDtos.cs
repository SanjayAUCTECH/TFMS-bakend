using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

public class CreateExpenseRequest
{
    public DateTime Date          { get; set; }
    public string   Mode          { get; set; } = string.Empty;
    public string   Head          { get; set; } = string.Empty;
    public int?     FundPoolId    { get; set; }
    public decimal  Amount        { get; set; }
    public string   Nature        { get; set; } = "HO";
    public int?     CampId        { get; set; }
    public string?  RecipientRole { get; set; }
    public int?     RecipientId   { get; set; }
    public string   RecipientName { get; set; } = string.Empty;
    public string   Purpose       { get; set; } = string.Empty;
}

public class UpdateExpenseRequest
{
    public DateTime Date          { get; set; }
    public string   Mode          { get; set; } = string.Empty;
    public string   Head          { get; set; } = string.Empty;
    public int?     FundPoolId    { get; set; }
    public decimal  Amount        { get; set; }
    public string   Nature        { get; set; } = "HO";
    public int?     CampId        { get; set; }
    public string?  RecipientRole { get; set; }
    public int?     RecipientId   { get; set; }
    public string   RecipientName { get; set; } = string.Empty;
    public string   Purpose       { get; set; } = string.Empty;
}

public class ExpenseListRequest : PagedRequest
{
    public string? DateFrom      { get; set; }
    public string? DateTo        { get; set; }
    public string? Head          { get; set; }
    public string? Nature        { get; set; }
    public int?    CampId        { get; set; }
    public string? RecipientRole { get; set; }
}

public class ExpenseResponse
{
    public int      Id            { get; set; }
    public string   ExpenseId     { get; set; } = string.Empty;
    public DateTime Date          { get; set; }
    public string   Mode          { get; set; } = string.Empty;
    public string   Head          { get; set; } = string.Empty;
    public string   FundPool      { get; set; } = string.Empty;
    public string   FundPoolName  { get; set; } = string.Empty;
    public decimal  Amount        { get; set; }
    public string   Nature        { get; set; } = string.Empty;
    public int?     CampId        { get; set; }
    public string   CampName      { get; set; } = string.Empty;
    public string   RecipientRole { get; set; } = string.Empty;
    public int?     RecipientId   { get; set; }
    public string   RecipientName { get; set; } = string.Empty;
    public string   Purpose       { get; set; } = string.Empty;
    public DateTime CreatedAt     { get; set; }
    public DateTime UpdatedAt     { get; set; }
}
