using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CreateRoomRequest
{
    [MaxLength(20)] public string  RoomNo       { get; set; } = string.Empty;
    public int?    CampId       { get; set; }
    public int?    FloorId      { get; set; }
    public decimal MonthlyPrice { get; set; }
    public string  Status       { get; set; } = "Vacant";
    public string  OtherDetails { get; set; } = string.Empty;
}

public class UpdateRoomRequest
{
    [MaxLength(20)] public string  RoomNo       { get; set; } = string.Empty;
    public int?    CampId       { get; set; }
    public int?    FloorId      { get; set; }
    public decimal MonthlyPrice { get; set; }
    public string  Status       { get; set; } = "Vacant";
    public string  OtherDetails { get; set; } = string.Empty;
}

public class RoomListRequest : Common.PagedRequest
{
    public int?    CampId  { get; set; }
    public int?    FloorId { get; set; }
    public string? RoomStatus { get; set; }   // Vacant | Occupied | Maintenance
}

public class RoomResponse
{
    public int      Id           { get; set; }
    public string   RoomNo       { get; set; } = string.Empty;
    public int      CampId       { get; set; }
    public string   CampName     { get; set; } = string.Empty;
    public int      FloorId      { get; set; }
    public string   FloorName    { get; set; } = string.Empty;
    public bool     Occupied     { get; set; }
    public decimal  MonthlyPrice { get; set; }
    public string   Status       { get; set; } = string.Empty;
    public string   OtherDetails { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
    public DateTime UpdatedAt    { get; set; }
}
