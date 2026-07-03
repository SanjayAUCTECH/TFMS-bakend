namespace TFMS_software_api.Models;

public class Camp
{
    public int              Id        { get; set; }
    public string           Code      { get; set; } = string.Empty;
    public string           Name      { get; set; } = string.Empty;
    public int              Rooms     { get; set; }
    public int              Floors    { get; set; }
    public string           Status    { get; set; } = "Active";
    public DateTime         CreatedAt { get; set; }
    public DateTime         UpdatedAt { get; set; }
    public List<CampPartner> Partners { get; set; } = new();
    public List<CampOwner>   Owners   { get; set; } = new();
}

public class CampPartner
{
    public int     Id          { get; set; }
    public int     CampId      { get; set; }
    public int     PartnerId   { get; set; }
    public string  PartnerName { get; set; } = string.Empty;
    public string  ShareType   { get; set; } = "percentage";
    public decimal ShareValue  { get; set; }
}

public class CampOwner
{
    public int     Id        { get; set; }
    public int     CampId    { get; set; }
    public int     OwnerId   { get; set; }
    public string  OwnerName { get; set; } = string.Empty;
    public string  ShareType { get; set; } = "percentage";
    public decimal ShareValue { get; set; }
}
