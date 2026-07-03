namespace TFMS_software_api.Models;

public class AppUser
{
    public int       Id           { get; set; }
    public string    UserId       { get; set; } = string.Empty;
    public string    Name         { get; set; } = string.Empty;
    public string    Username     { get; set; } = string.Empty;
    public string    PasswordHash { get; set; } = string.Empty;
    public string    Role         { get; set; } = string.Empty;
    public string    Source       { get; set; } = string.Empty;
    public int?      SourceId     { get; set; }
    public string    Contact      { get; set; } = string.Empty;
    public string    Email        { get; set; } = string.Empty;
    public string    LoginAccess  { get; set; } = "enabled";
    public string    Status       { get; set; } = "Active";
    public DateTime? LastLogin    { get; set; }
    public string    MenuAccess   { get; set; } = "{}";
    public bool      IsAdmin      { get; set; }
    public DateTime  CreatedAt    { get; set; }
    public DateTime  UpdatedAt    { get; set; }
}
