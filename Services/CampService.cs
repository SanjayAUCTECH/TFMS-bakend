using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class CampService : ICampService
{
    private readonly ICampRepository _repo;
    public CampService(ICampRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<CampResponse>>> GetAllAsync(CampListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var cards = await _repo.GetStatsAsync();
        return ApiResponse<IEnumerable<CampResponse>>.Ok(
            data.Select(ToResponse), "Camps retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize), cards);
    }

    public async Task<ApiResponse<IEnumerable<CampResponse>>> GetAllActiveAsync()
        => ApiResponse<IEnumerable<CampResponse>>.Ok((await _repo.GetAllActiveAsync()).Select(ToResponse));

    public async Task<ApiResponse<CampResponse>> GetByIdAsync(int id)
    {
        var c = await _repo.GetByIdAsync(id);
        return c == null ? ApiResponse<CampResponse>.Fail("Not found.") : ApiResponse<CampResponse>.Ok(ToResponse(c));
    }

    public async Task<ApiResponse<CampResponse>> CreateAsync(CreateCampRequest request)
    {
        var camp = new Camp
        {
            Name               = request.Name.Trim(),
            Status             = request.Status,
            CampPropertyUsage  = request.CampPropertyUsage?.Trim() ?? "",
            CampBuildingName   = request.CampBuildingName?.Trim()  ?? "",
            CampPropertyType   = request.CampPropertyType?.Trim()  ?? "",
            CampLocation       = request.CampLocation?.Trim()      ?? "",
            CampPropertyNo     = request.CampPropertyNo?.Trim()    ?? "",
            CampPropertyArea   = request.CampPropertyArea?.Trim()  ?? "",
            CampPremisesNo     = request.CampPremisesNo?.Trim()    ?? "",
            CampPlotNo         = request.CampPlotNo?.Trim()        ?? "",
            CampMakaniNo       = request.CampMakaniNo?.Trim()      ?? "",
            Partners = request.Partners.Select(p => new CampPartner { PartnerId = p.PartnerId ?? 0, ShareType = p.ShareType, ShareValue = p.ShareValue }).ToList(),
            Owners   = request.Owners.Select(o => new CampOwner   { OwnerId   = o.OwnerId   ?? 0, ShareType = o.ShareType, ShareValue = o.ShareValue }).ToList(),
        };
        var id = await _repo.CreateAsync(camp);
        return ApiResponse<CampResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Camp created.");
    }

    public async Task<ApiResponse<CampResponse>> UpdateAsync(int id, UpdateCampRequest request)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<CampResponse>.Fail("Not found.");
        var camp = new Camp
        {
            Id                 = id,
            Name               = request.Name.Trim(),
            Status             = request.Status,
            CampPropertyUsage  = request.CampPropertyUsage?.Trim() ?? "",
            CampBuildingName   = request.CampBuildingName?.Trim()  ?? "",
            CampPropertyType   = request.CampPropertyType?.Trim()  ?? "",
            CampLocation       = request.CampLocation?.Trim()      ?? "",
            CampPropertyNo     = request.CampPropertyNo?.Trim()    ?? "",
            CampPropertyArea   = request.CampPropertyArea?.Trim()  ?? "",
            CampPremisesNo     = request.CampPremisesNo?.Trim()    ?? "",
            CampPlotNo         = request.CampPlotNo?.Trim()        ?? "",
            CampMakaniNo       = request.CampMakaniNo?.Trim()      ?? "",
            Partners = request.Partners.Select(p => new CampPartner { PartnerId = p.PartnerId ?? 0, ShareType = p.ShareType, ShareValue = p.ShareValue }).ToList(),
            Owners   = request.Owners.Select(o => new CampOwner   { OwnerId   = o.OwnerId   ?? 0, ShareType = o.ShareType, ShareValue = o.ShareValue }).ToList(),
        };
        await _repo.UpdateAsync(camp);
        return ApiResponse<CampResponse>.Ok(ToResponse((await _repo.GetByIdAsync(id))!), "Camp updated.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (await _repo.GetByIdAsync(id) == null) return ApiResponse<bool>.Fail("Not found.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static CampResponse ToResponse(Camp c) => new()
    {
        Id                = c.Id,
        Code              = c.Code,
        Name              = c.Name,
        Rooms             = c.Rooms,
        Floors            = c.Floors,
        Status            = c.Status,
        CampPropertyUsage = c.CampPropertyUsage,
        CampBuildingName  = c.CampBuildingName,
        CampPropertyType  = c.CampPropertyType,
        CampLocation      = c.CampLocation,
        CampPropertyNo    = c.CampPropertyNo,
        CampPropertyArea  = c.CampPropertyArea,
        CampPremisesNo    = c.CampPremisesNo,
        CampPlotNo        = c.CampPlotNo,
        CampMakaniNo      = c.CampMakaniNo,
        CreatedAt         = c.CreatedAt,
        UpdatedAt         = c.UpdatedAt,
        Partners = c.Partners.Select(p => new CampPartnerResponse
            { Id = p.Id, PartnerId = p.PartnerId, PartnerName = p.PartnerName, ShareType = p.ShareType, ShareValue = p.ShareValue }).ToList(),
        Owners = c.Owners.Select(o => new CampOwnerResponse
            { Id = o.Id, OwnerId = o.OwnerId, OwnerName = o.OwnerName, ShareType = o.ShareType, ShareValue = o.ShareValue }).ToList(),
    };
}
