using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateAccountsHeadRequest
{
    [Required, MaxLength(200)] public string Name   { get; set; } = string.Empty;
    [Required, MaxLength(30)]  public string Type   { get; set; } = string.Empty;   // Asset|Liability|Income|Expense|Capital
    public string Status { get; set; } = "Active";
}

public class UpdateAccountsHeadRequest
{
    [Required, MaxLength(200)] public string Name   { get; set; } = string.Empty;
    [Required, MaxLength(30)]  public string Type   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class AccountsHeadListRequest : Common.PagedRequest
{
    public string? Type { get; set; }   // optional type filter
}

public class AccountsHeadResponse
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Type      { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
