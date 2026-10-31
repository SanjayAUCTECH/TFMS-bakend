using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateBackupDto
{
    [Required]
    public DateTime BackupDate { get; set; }
    
    [Required]
    public string BackupName { get; set; } = string.Empty;
    
    [Required]
    public string Location { get; set; } = string.Empty;
    
    public string? Remarks { get; set; }
}

public class BackupListDto
{
    public int      Id         { get; set; }
    public DateTime BackupDate { get; set; }
    public string   BackupName { get; set; } = string.Empty;
    public string   Location   { get; set; } = string.Empty;
    public string?  Remarks    { get; set; }
    public string?  AddedBy    { get; set; }
    public DateTime CreatedAt  { get; set; }
}
