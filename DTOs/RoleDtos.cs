namespace TFMS_software_api.DTOs;

public class CreateRoleRequest
{
    public string RoleName { get; set; } = string.Empty;
    public string Status   { get; set; } = "Active";
}

public class UpdateRoleRequest
{
    public string RoleName { get; set; } = string.Empty;
    public string Status   { get; set; } = "Active";
}

public class RoleListRequest : Common.PagedRequest { }

public class RoleResponse
{
    public int      Id        { get; set; }
    public string   RoleCode  { get; set; } = string.Empty;
    public string   RoleName  { get; set; } = string.Empty;
    public string   Status    { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
