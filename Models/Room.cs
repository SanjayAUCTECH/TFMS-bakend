namespace TFMS_software_api.Models;

public class Room
{
    public int      Id           { get; set; }
    public string   RoomNo       { get; set; } = string.Empty;
    public int      CampId       { get; set; }
    public string   CampName     { get; set; } = string.Empty;
    public int      FloorId      { get; set; }
    public string   FloorName    { get; set; } = string.Empty;
    public bool     Occupied     { get; set; }
    public decimal  MonthlyPrice { get; set; }
    public string   Status       { get; set; } = "Vacant";
    public string   OtherDetails { get; set; } = string.Empty;
    public DateTime CreatedAt    { get; set; }
    public DateTime UpdatedAt    { get; set; }
}
