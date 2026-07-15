using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateRoomStatusRequest
{
    [Required] public string Name { get; set; } = string.Empty;
}

public class UpdateRoomStatusRequest
{
    [Required] public string Name { get; set; } = string.Empty;
}

public class RoomStatusResponse
{
    public int    Id   { get; set; }
    public string Name { get; set; } = string.Empty;
}
