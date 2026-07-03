using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateFundPoolRequest
{
    [Required, MaxLength(200)] public string  Name    { get; set; } = string.Empty;
    public decimal Balance { get; set; } = 0;
    public string  Status  { get; set; } = "Active";
}

public class UpdateFundPoolRequest
{
    [Required, MaxLength(200)] public string  Name    { get; set; } = string.Empty;
    public decimal Balance { get; set; }
    public string  Status  { get; set; } = "Active";
}

public class FundPoolListRequest : Common.PagedRequest { }

public class FundPoolResponse
{
    public int      Id        { get; set; }
    public string   Code      { get; set; } = string.Empty;
    public string   Name      { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public decimal  Balance   { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
