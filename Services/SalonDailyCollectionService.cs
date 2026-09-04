using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonDailyCollectionService : ISalonDailyCollectionService
{
    private readonly ISalonDailyCollectionRepository _repo;
    public SalonDailyCollectionService(ISalonDailyCollectionRepository repo) => _repo = repo;

    // ── COMBINED DAILY POSTING ─────────────────────────────────────────────────
    public async Task<ApiResponse<SalonDailyPostingResponse>> PostDailyAsync(
        SalonDailyPostingRequest request, string? addedBy = null)
    {
        int collInserted = 0, expInserted = 0;

        if (request.Collections?.Count > 0)
            collInserted = await _repo.BulkCreateCollectionsAsync(request.Collections, addedBy);

        if (request.Expences?.Count > 0)
            expInserted = await _repo.BulkCreateExpencesAsync(request.Expences, addedBy);

        return ApiResponse<SalonDailyPostingResponse>.Ok(new SalonDailyPostingResponse
        {
            CollectionsInserted = collInserted,
            ExpencesInserted    = expInserted,
            Message = $"{collInserted} collection(s) and {expInserted} expense(s) posted successfully."
        }, "Daily posting completed.");
    }

    // ── SDCollection ───────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<SDCollectionResponse>>> GetAllCollectionsAsync(
        SDCollectionListRequest request)
    {
        var (data, total) = await _repo.GetAllCollectionsAsync(request);
        return ApiResponse<IEnumerable<SDCollectionResponse>>.Ok(
            data.Select(ToCollectionResponse),
            "Collections retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<SDCollectionResponse>> GetCollectionByIdAsync(int id)
    {
        var item = await _repo.GetCollectionByIdAsync(id);
        return item is null
            ? ApiResponse<SDCollectionResponse>.Fail("Collection not found.")
            : ApiResponse<SDCollectionResponse>.Ok(ToCollectionResponse(item));
    }

    public async Task<ApiResponse<SalonDailyPostingResponse>> BulkCreateCollectionsAsync(
        BulkCreateSDCollectionRequest request, string? addedBy = null)
    {
        var count = await _repo.BulkCreateCollectionsAsync(request.Collections, addedBy);
        return ApiResponse<SalonDailyPostingResponse>.Ok(new SalonDailyPostingResponse
        {
            CollectionsInserted = count,
            Message = $"{count} collection(s) inserted successfully."
        }, "Collections inserted.");
    }

    public async Task<ApiResponse<SDCollectionResponse>> UpdateCollectionAsync(
        int id, UpdateSDCollectionRequest request, int? userId = null)
    {
        if (await _repo.GetCollectionByIdAsync(id) is null)
            return ApiResponse<SDCollectionResponse>.Fail("Collection not found.");

        await _repo.UpdateCollectionAsync(new SDCollection
        {
            CollectionId = id,
            Date         = request.Date,
            SalonId      = request.SalonId,
            StaffId      = request.StaffId,
            HeadId       = request.HeadId,
            Mode         = request.Mode,
            Amount       = request.Amount,
            Description  = request.Description?.Trim(),
            Status       = request.Status,
            UpdatedBy    = userId
        });

        var updated = await _repo.GetCollectionByIdAsync(id);
        return ApiResponse<SDCollectionResponse>.Ok(ToCollectionResponse(updated!), "Collection updated.");
    }

    public async Task<ApiResponse<bool>> DeleteCollectionAsync(int id, int? userId = null)
    {
        if (await _repo.GetCollectionByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Collection not found.");

        var deleted = await _repo.DeleteCollectionAsync(id, userId?.ToString());
        return deleted
            ? ApiResponse<bool>.Ok(true, "Collection deleted successfully.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    // ── SDExpence ──────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<SDExpenceResponse>>> GetAllExpencesAsync(
        SDExpenceListRequest request)
    {
        var (data, total) = await _repo.GetAllExpencesAsync(request);
        return ApiResponse<IEnumerable<SDExpenceResponse>>.Ok(
            data.Select(ToExpenceResponse),
            "Expenses retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<SDExpenceResponse>> GetExpenceByIdAsync(int id)
    {
        var item = await _repo.GetExpenceByIdAsync(id);
        return item is null
            ? ApiResponse<SDExpenceResponse>.Fail("Expense not found.")
            : ApiResponse<SDExpenceResponse>.Ok(ToExpenceResponse(item));
    }

    public async Task<ApiResponse<SalonDailyPostingResponse>> BulkCreateExpencesAsync(
        BulkCreateSDExpenceRequest request, string? addedBy = null)
    {
        var count = await _repo.BulkCreateExpencesAsync(request.Expences, addedBy);
        return ApiResponse<SalonDailyPostingResponse>.Ok(new SalonDailyPostingResponse
        {
            ExpencesInserted = count,
            Message = $"{count} expense(s) inserted successfully."
        }, "Expenses inserted.");
    }

    public async Task<ApiResponse<SDExpenceResponse>> UpdateExpenceAsync(
        int id, UpdateSDExpenceRequest request, int? userId = null)
    {
        if (await _repo.GetExpenceByIdAsync(id) is null)
            return ApiResponse<SDExpenceResponse>.Fail("Expense not found.");

        await _repo.UpdateExpenceAsync(new SDExpence
        {
            ExpenceId     = id,
            Date          = request.Date,
            SalonId       = request.SalonId,
            HeadId        = request.HeadId,
            ExpenceType   = request.ExpenceType,
            Mode          = request.Mode,
            Amount        = request.Amount,
            Description   = request.Description?.Trim(),
            Status        = request.Status,
            UpdatedBy     = userId
        });

        var updated = await _repo.GetExpenceByIdAsync(id);
        return ApiResponse<SDExpenceResponse>.Ok(ToExpenceResponse(updated!), "Expense updated.");
    }

    public async Task<ApiResponse<bool>> DeleteExpenceAsync(int id, int? userId = null)
    {
        if (await _repo.GetExpenceByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Expense not found.");

        var deleted = await _repo.DeleteExpenceAsync(id, userId?.ToString());
        return deleted
            ? ApiResponse<bool>.Ok(true, "Expense deleted successfully.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    // ── Mappers ────────────────────────────────────────────────────────────────
    private static SDCollectionResponse ToCollectionResponse(SDCollection c) => new()
    {
        CollectionId = c.CollectionId, Date = c.Date,
        SalonId = c.SalonId, SalonName = c.SalonName,
        StaffId = c.StaffId, StaffName = c.StaffName,
        HeadId = c.HeadId, HeadName = c.HeadName,
        Mode = c.Mode, Amount = c.Amount,
        Description = c.Description, Status = c.Status,
        CreatedAt = c.CreatedAt, UpdatedAt = c.UpdatedAt
    };

    private static SDExpenceResponse ToExpenceResponse(SDExpence e) => new()
    {
        ExpenceId = e.ExpenceId, Date = e.Date,
        SalonId = e.SalonId, SalonName = e.SalonName,
        HeadId = e.HeadId, HeadName = e.HeadName,
        ExpenceType = e.ExpenceType,
        Mode = e.Mode, Amount = e.Amount,
        Description = e.Description, Status = e.Status,
        CreatedAt = e.CreatedAt, UpdatedAt = e.UpdatedAt
    };
}
