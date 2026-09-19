using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class OutsourceMoneyService : IOutsourceMoneyService
{
    private readonly IOutsourceMoneyRepository _repo;
    public OutsourceMoneyService(IOutsourceMoneyRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<OutsourceMoneyResponse>>> GetAllAsync(OutsourceMoneyListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var cards = await _repo.GetStatsAsync();
        return ApiResponse<IEnumerable<OutsourceMoneyResponse>>.Ok(
            data.Select(ToResponse),
            "Outsource Money records retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize),
            cards);
    }

    public async Task<ApiResponse<OutsourceMoneyResponse>> GetByIdAsync(int id)
    {
        var entity = await _repo.GetByIdAsync(id);
        return entity == null
            ? ApiResponse<OutsourceMoneyResponse>.Fail("Outsource Money record not found.")
            : ApiResponse<OutsourceMoneyResponse>.Ok(ToResponse(entity));
    }

    public async Task<ApiResponse<OutsourceMoneyResponse>> CreateAsync(CreateOutsourceMoneyRequest request, int? userId = null)
    {
        var entity = new OutsourceMoney
        {
            Date        = DateTime.Parse(request.Date),
            Month       = request.Month?.Trim() ?? DateTime.Parse(request.Date).ToString("MMMM yyyy"),
            CampId      = request.CampId ?? 0,
            FundPoolId  = request.FundPoolId ?? 0,
            Amount      = request.Amount,
            Mode        = request.Mode.Trim(),
            Purpose     = request.Purpose.Trim(),
            Remarks     = request.Remarks?.Trim() ?? string.Empty,
            ReferenceNo = request.ReferenceNo?.Trim() ?? string.Empty,
            AddedBy     = userId
        };

        var id = await _repo.CreateAsync(entity);
        var created = await _repo.GetByIdAsync(id);

        return ApiResponse<OutsourceMoneyResponse>.Ok(
            ToResponse(created!),
            "Outsource Money record created successfully.");
    }

    public async Task<ApiResponse<OutsourceMoneyResponse>> UpdateAsync(int id, UpdateOutsourceMoneyRequest request, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null)
            return ApiResponse<OutsourceMoneyResponse>.Fail("Outsource Money record not found.");

        // Auto-generate Month from Date if not provided
        var parsedDate = DateTime.Parse(request.Date);
        var month = string.IsNullOrWhiteSpace(request.Month) 
            ? parsedDate.ToString("MMMM yyyy") 
            : request.Month.Trim();

        var entity = new OutsourceMoney
        {
            Id          = id,
            Date        = parsedDate,
            Month       = month,
            CampId      = request.CampId ?? 0,
            FundPoolId  = request.FundPoolId ?? 0,
            Amount      = request.Amount,
            Mode        = request.Mode.Trim(),
            Purpose     = request.Purpose.Trim(),
            Remarks     = request.Remarks?.Trim() ?? string.Empty,
            ReferenceNo = request.ReferenceNo?.Trim() ?? string.Empty,
            UpdatedBy   = userId
        };

        await _repo.UpdateAsync(entity);
        var updated = await _repo.GetByIdAsync(id);

        return ApiResponse<OutsourceMoneyResponse>.Ok(
            ToResponse(updated!),
            "Outsource Money record updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null)
            return ApiResponse<bool>.Fail("Outsource Money record not found or already deleted.");

        var deleted = await _repo.DeleteAsync(id, userId);
        return deleted
            ? ApiResponse<bool>.Ok(true, "Outsource Money record deleted successfully.")
            : ApiResponse<bool>.Fail("Failed to delete Outsource Money record.");
    }

    private static OutsourceMoneyResponse ToResponse(OutsourceMoney entity) => new()
    {
        Id           = entity.Id,
        Date         = entity.Date.ToString("yyyy-MM-dd"),
        Month        = entity.Month,
        CampId       = entity.CampId,
        CampName     = entity.CampName,
        FundPoolId   = entity.FundPoolId,
        FundPoolName = entity.FundPoolName,
        Amount       = entity.Amount,
        Mode         = entity.Mode,
        Purpose      = entity.Purpose,
        Remarks      = entity.Remarks,
        ReferenceNo  = entity.ReferenceNo,
        CreatedAt    = entity.CreatedAt,
        UpdatedAt    = entity.UpdatedAt
    };
}
