namespace TFMS_software_api.DTOs;

public class CreateAccountsHeadRequest
{
    public string Name   { get; set; } = string.Empty;
    public string Type   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class UpdateAccountsHeadRequest
{
    public string Name   { get; set; } = string.Empty;
    public string Type   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class AccountsHeadListRequest : Common.PagedRequest
{
    public string? Type { get; set; }
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
