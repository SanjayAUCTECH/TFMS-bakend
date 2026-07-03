namespace TFMS_software_api.Models;

public class Contract
{
    public int           Id            { get; set; }
    public string        ContractId    { get; set; } = string.Empty;
    public int           TenantId      { get; set; }
    public string        TenantName    { get; set; } = string.Empty;
    public int           CampId        { get; set; }
    public string        CampName      { get; set; } = string.Empty;
    public DateTime      StartDate     { get; set; }
    public int           Months        { get; set; }
    public DateTime      EndDate       { get; set; }
    public decimal       MonthlyTotal  { get; set; }
    public decimal       ContractTotal { get; set; }
    public string        Status        { get; set; } = "Active";
    public DateTime      CreatedAt     { get; set; }
    public DateTime      UpdatedAt     { get; set; }
    public List<int>     RoomIds       { get; set; } = new();
    public List<Payment> Payments      { get; set; } = new();
}

public class ContractRoom
{
    public int    Id         { get; set; }
    public string ContractId { get; set; } = string.Empty;
    public int    RoomId     { get; set; }
}
