using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateRoomStatusRequest
{
    [Required, MaxLength(50)] public string Name { get; set; } = string.Empty;
}

public class UpdateRoomStatusRequest
{
    [Required, MaxLength(50)] public string Name { get; set; } = string.Empty;
}

public class RoomStatusResponse
{
    public int    Id   { get; set; }
    public string Name { get; set; } = string.Empty;
}
