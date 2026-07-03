using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreatePaymentModeRequest
{
    [Required, MaxLength(50)] public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class UpdatePaymentModeRequest
{
    [Required, MaxLength(50)] public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class PaymentModeResponse
{
    public int    Id     { get; set; }
    public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
