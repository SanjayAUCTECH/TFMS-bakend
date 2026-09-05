using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class CompanyExpensePostingService : ICompanyExpensePostingService
{
    private readonly ICompanyExpensePostingRepository _repo;

    public CompanyExpensePostingService(ICompanyExpensePostingRepository repo) => _repo = repo;

    // ── GET ALL ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<CompanyExpensePostingResponse>>> GetAllAsync(
        CompanyExpensePostingListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<CompanyExpensePostingResponse>>.Ok(
            data.Select(ToResponse),
            "Company expenses retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    // ── GET BY ID ──────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CompanyExpensePostingResponse>> GetByIdAsync(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item is null
            ? ApiResponse<CompanyExpensePostingResponse>.Fail("Company expense not found.")
            : ApiResponse<CompanyExpensePostingResponse>.Ok(ToResponse(item));
    }

    // ── CREATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CompanyExpensePostingResponse>> CreateAsync(
        CreateCompanyExpensePostingRequest request, string? addedBy)
    {
        var model = new CompanyExpensePosting
        {
            Date          = request.Date.Date,
            Type          = request.Type.Trim(),
            RecipientName = request.RecipientName?.Trim(),
            RecipientId   = request.RecipientId,
            Head          = request.Head?.Trim(),
            Amount        = request.Amount,
            Mode          = request.Mode.Trim(),
            SalonId       = request.SalonId,
            Description   = request.Description?.Trim(),
            Status        = request.Status,
            AddedBy       = addedBy,
        };

        int newId = await _repo.CreateAsync(model);
        if (newId <= 0)
            return ApiResponse<CompanyExpensePostingResponse>.Fail("Failed to create company expense.");

        var created = await _repo.GetByIdAsync(newId);
        return ApiResponse<CompanyExpensePostingResponse>.Ok(ToResponse(created!), "Company expense created successfully.");
    }

    // ── UPDATE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CompanyExpensePostingResponse>> UpdateAsync(
        int id, UpdateCompanyExpensePostingRequest request, int? userId)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<CompanyExpensePostingResponse>.Fail("Company expense not found.");

        var model = new CompanyExpensePosting
        {
            Id            = id,
            Date          = request.Date.Date,
            Type          = request.Type.Trim(),
            RecipientName = request.RecipientName?.Trim(),
            RecipientId   = request.RecipientId,
            Head          = request.Head?.Trim(),
            Amount        = request.Amount,
            Mode          = request.Mode.Trim(),
            SalonId       = request.SalonId,
            Description   = request.Description?.Trim(),
            Status        = request.Status,
            UpdatedBy     = userId,
        };

        bool updated = await _repo.UpdateAsync(model);
        if (!updated)
            return ApiResponse<CompanyExpensePostingResponse>.Fail("Update failed.");

        var result = await _repo.GetByIdAsync(id);
        return ApiResponse<CompanyExpensePostingResponse>.Ok(ToResponse(result!), "Company expense updated successfully.");
    }

    // ── DELETE ─────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<bool>> DeleteAsync(int id, string? deletedBy)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Company expense not found.");

        bool deleted = await _repo.DeleteAsync(id, deletedBy);
        return deleted
            ? ApiResponse<bool>.Ok(true, "Company expense deleted successfully.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    // ── SUMMARY ────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<IEnumerable<CompanyExpenseSummaryResponse>>> GetSummaryAsync(
        int? salonId, string? dateFrom, string? dateTo)
    {
        var data = await _repo.GetSummaryAsync(salonId, dateFrom, dateTo);
        return ApiResponse<IEnumerable<CompanyExpenseSummaryResponse>>.Ok(
            data, "Summary retrieved successfully.");
    }

    // ── Mapper ─────────────────────────────────────────────────────────────────
    private static CompanyExpensePostingResponse ToResponse(CompanyExpensePosting m) => new()
    {
        Id            = m.Id,
        Date          = m.Date,
        Type          = m.Type,
        RecipientName = m.RecipientName,
        RecipientId   = m.RecipientId,
        Head          = m.Head,
        Amount        = m.Amount,
        Mode          = m.Mode,
        SalonId       = m.SalonId,
        SalonName     = m.SalonName,
        Description   = m.Description,
        Status        = m.Status,
        CreatedAt     = m.CreatedAt,
        UpdatedAt     = m.UpdatedAt,
    };
}
