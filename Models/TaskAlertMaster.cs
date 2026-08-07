namespace TFMS_software_api.Models;

public class TaskAlertMaster
{
    public int      Id               { get; set; }
    public string   TaskId           { get; set; } = string.Empty;
    public DateTime TaskDate         { get; set; }
    public string   TaskTitle        { get; set; } = string.Empty;
    public string   TaskDescription  { get; set; } = string.Empty;
    public string   TaskStatus       { get; set; } = "Running"; // Running|Complete|Partial|Cancel
    public string   PartialRemark    { get; set; } = string.Empty;
    public int?     AssignPersonId   { get; set; }
    public string   AssignPersonName { get; set; } = string.Empty;
    public DateTime CreatedAt        { get; set; }
    public DateTime UpdatedAt        { get; set; }
    // Audit
    public int?  AddedBy   { get; set; }
    public int?  UpdatedBy { get; set; }
    public int?  DeletedBy { get; set; }
    public bool  IsDeleted { get; set; }
}
