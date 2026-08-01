using Swashbuckle.AspNetCore.Annotations;
using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

/// <summary>Owner Contract cancel karne ka request</summary>
public class CancelOwnerContractRequest
{
    [Required, SwaggerSchema("Owner Contract ID (numeric Id)")]
    public int     OwnerContractId    { get; set; }

    [Required, SwaggerSchema("Cancellation date (yyyy-MM-dd)")]
    public string  CancellationDate   { get; set; } = string.Empty;

    [SwaggerSchema("Cancellation reason / remarks")]
    public string? Remarks            { get; set; }

    [SwaggerSchema("Cancelled by (person name or designation)")]
    public string? CancelledBy        { get; set; }
}

/// <summary>Owner Contract cancellation response</summary>
public class OwnerContractCancellationResponse
{
    public int      Id                 { get; set; }
    public string   CancellationCode   { get; set; } = string.Empty;
    public int      OwnerContractId    { get; set; }
    public string   OcCode             { get; set; } = string.Empty;
    public int      CampId             { get; set; }
    public string   CampName           { get; set; } = string.Empty;
    public int      OwnerId            { get; set; }
    public string   OwnerName          { get; set; } = string.Empty;
    public string   CancellationDate   { get; set; } = string.Empty;
    public string?  Remarks            { get; set; }
    public string?  CancelledBy        { get; set; }
    public int?     CancelledByUserId  { get; set; }
    public string   Status             { get; set; } = string.Empty;
    public DateTime CreatedAt          { get; set; }
}
