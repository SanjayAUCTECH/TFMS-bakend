using TFMS_software_api.Common;

namespace TFMS_software_api.DTOs;

public class CreateTaskAlertRequest
{
    public DateTime TaskDate         { get; set; }
    public string   TaskTitle        { get; set; } = string.Empty;
    public string   TaskDescription  { get; set; } = string.Empty;
    public string   TaskStatus       { get; set; } = "Running";
    public string   PartialRemark    { get; set; } = string.Empty;
    public int?     AssignPersonId   { get; set; }
    public string   AssignPersonName { get; set; } = string.Empty;
}

public class UpdateTaskAlertRequest
{
    public DateTime TaskDate         { get; set; }
    public string   TaskTitle        { get; set; } = string.Empty;
    public string   TaskDescription  { get; set; } = string.Empty;
    public string   TaskStatus       { get; set; } = "Running";
    public string   PartialRemark    { get; set; } = string.Empty;
    public int?     AssignPersonId   { get; set; }
    public string   AssignPersonName { get; set; } = string.Empty;
}

public class TaskAlertListRequest : PagedRequest
{
    public string? TaskStatus      { get; set; }
    public int?    AssignPersonId  { get; set; }
    public string? DateFrom        { get; set; }
    public string? DateTo          { get; set; }
}

public class TaskAlertResponse
{
    public int      Id               { get; set; }
    public string   TaskId           { get; set; } = string.Empty;
    public DateTime TaskDate         { get; set; }
    public string   TaskTitle        { get; set; } = string.Empty;
    public string   TaskDescription  { get; set; } = string.Empty;
    public string   TaskStatus       { get; set; } = string.Empty;
    public string   PartialRemark    { get; set; } = string.Empty;
    public int?     AssignPersonId   { get; set; }
    public string   AssignPersonName { get; set; } = string.Empty;
    public DateTime CreatedAt        { get; set; }
    public DateTime UpdatedAt        { get; set; }
}

public class TaskAlertActiveResponse : TaskAlertResponse
{
    public int DaysOverdue { get; set; }
}
