using System.ComponentModel.DataAnnotations;

namespace TFMS_software_api.DTOs;

public class CampPartnerRequest
{
    public int?    PartnerId  { get; set; }
    public string  ShareType  { get; set; } = "percentage";
    public decimal ShareValue { get; set; }
}

public class CampOwnerRequest
{
    public int?    OwnerId    { get; set; }
    public string  ShareType  { get; set; } = "percentage";
    public decimal ShareValue { get; set; }
}

public class CreateCampRequest
{
    [MaxLength(200)] public string Name               { get; set; } = string.Empty;
    public string Status             { get; set; } = "Active";
    [MaxLength(30)]  public string CampPropertyUsage  { get; set; } = string.Empty;
    [MaxLength(200)] public string CampBuildingName   { get; set; } = string.Empty;
    [MaxLength(100)] public string CampPropertyType   { get; set; } = string.Empty;
    [MaxLength(300)] public string CampLocation       { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPropertyNo     { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPropertyArea   { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPremisesNo     { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPlotNo         { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampMakaniNo       { get; set; } = string.Empty;
    public List<CampPartnerRequest> Partners { get; set; } = new();
    public List<CampOwnerRequest>   Owners   { get; set; } = new();
}

public class UpdateCampRequest
{
    [MaxLength(200)] public string Name               { get; set; } = string.Empty;
    public string Status             { get; set; } = "Active";
    [MaxLength(30)]  public string CampPropertyUsage  { get; set; } = string.Empty;
    [MaxLength(200)] public string CampBuildingName   { get; set; } = string.Empty;
    [MaxLength(100)] public string CampPropertyType   { get; set; } = string.Empty;
    [MaxLength(300)] public string CampLocation       { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPropertyNo     { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPropertyArea   { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPremisesNo     { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampPlotNo         { get; set; } = string.Empty;
    [MaxLength(50)]  public string CampMakaniNo       { get; set; } = string.Empty;
    public List<CampPartnerRequest> Partners { get; set; } = new();
    public List<CampOwnerRequest>   Owners   { get; set; } = new();
}

public class CampListRequest : Common.PagedRequest { }

public class CampPartnerResponse
{
    public int     Id          { get; set; }
    public int     PartnerId   { get; set; }
    public string  PartnerName { get; set; } = string.Empty;
    public string  ShareType   { get; set; } = string.Empty;
    public decimal ShareValue  { get; set; }
}

public class CampOwnerResponse
{
    public int     Id        { get; set; }
    public int     OwnerId   { get; set; }
    public string  OwnerName { get; set; } = string.Empty;
    public string  ShareType { get; set; } = string.Empty;
    public decimal ShareValue { get; set; }
}

public class CampResponse
{
    public int      Id                 { get; set; }
    public string   Code               { get; set; } = string.Empty;
    public string   Name               { get; set; } = string.Empty;
    public int      Rooms              { get; set; }
    public int      Floors             { get; set; }
    public string   Status             { get; set; } = string.Empty;
    public string   CampPropertyUsage  { get; set; } = string.Empty;
    public string   CampBuildingName   { get; set; } = string.Empty;
    public string   CampPropertyType   { get; set; } = string.Empty;
    public string   CampLocation       { get; set; } = string.Empty;
    public string   CampPropertyNo     { get; set; } = string.Empty;
    public string   CampPropertyArea   { get; set; } = string.Empty;
    public string   CampPremisesNo     { get; set; } = string.Empty;
    public string   CampPlotNo         { get; set; } = string.Empty;
    public string   CampMakaniNo       { get; set; } = string.Empty;
    public DateTime CreatedAt          { get; set; }
    public DateTime UpdatedAt          { get; set; }
    public List<CampPartnerResponse> Partners { get; set; } = new();
    public List<CampOwnerResponse>   Owners   { get; set; } = new();
}
