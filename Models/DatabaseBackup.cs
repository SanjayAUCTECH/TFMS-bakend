namespace TFMS_software_api.Models;

public class DatabaseBackup
{
    public int      Id          { get; set; }
    public DateTime BackupDate  { get; set; }
    public string   BackupName  { get; set; } = string.Empty;
    public string   Location    { get; set; } = string.Empty;
    public string?  Remarks     { get; set; }
    public string?  AddedBy     { get; set; }
    public DateTime CreatedAt   { get; set; }
}
