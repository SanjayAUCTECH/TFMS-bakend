using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateSalonMasterRequest
{
    [Required(ErrorMessage = "Name is required.")]
    [MaxLength(150, ErrorMessage = "Name cannot exceed 150 characters.")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Address is required.")]
    [MaxLength(300, ErrorMessage = "Address cannot exceed 300 characters.")]
    public string Address { get; set; } = string.Empty;

    [Required(ErrorMessage = "Contact is required.")]
    [MaxLength(20, ErrorMessage = "Contact cannot exceed 20 characters.")]
    public string Contact { get; set; } = string.Empty;

    [MaxLength(500, ErrorMessage = "Description cannot exceed 500 characters.")]
    public string? Description { get; set; }

    [MaxLength(1000)]
    public string? ThumbnailImage { get; set; }   // Cloudinary URL

    public string Status { get; set; } = "Active";
}

public class UpdateSalonMasterRequest
{
    [Required(ErrorMessage = "Name is required.")]
    [MaxLength(150)]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Address is required.")]
    [MaxLength(300)]
    public string Address { get; set; } = string.Empty;

    [Required(ErrorMessage = "Contact is required.")]
    [MaxLength(20)]
    public string Contact { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    [MaxLength(1000)]
    public string? ThumbnailImage { get; set; }

    public string Status { get; set; } = "Active";
}

public class SalonMasterListRequest : Common.PagedRequest { }

public class SalonMasterResponse
{
    public int      Id             { get; set; }
    public string   Name           { get; set; } = string.Empty;
    public string   Address        { get; set; } = string.Empty;
    public string   Contact        { get; set; } = string.Empty;
    public string?  Description    { get; set; }
    public string?  ThumbnailImage { get; set; }
    public string   Status         { get; set; } = string.Empty;
    public DateTime  CreatedAt     { get; set; }
    public DateTime? UpdatedAt     { get; set; }
}
