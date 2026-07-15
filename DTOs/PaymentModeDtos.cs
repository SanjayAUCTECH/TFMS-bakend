namespace TFMS_software_api.DTOs;

public class CreatePaymentModeRequest
{
    public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class UpdatePaymentModeRequest
{
    public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = "Active";
}

public class PaymentModeResponse
{
    public int    Id     { get; set; }
    public string Name   { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
