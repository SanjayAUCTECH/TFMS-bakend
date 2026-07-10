using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class ExpenseService : IExpenseService
{
    private readonly IExpenseRepository  _repo;
    private readonly IFundPoolRepository _fundRepo;
    private readonly ICampRepository     _campRepo;

    public ExpenseService(IExpenseRepository repo, IFundPoolRepository fundRepo, ICampRepository campRepo)
    {
        _repo = repo; _fundRepo = fundRepo; _campRepo = campRepo;
    }

    public async Task<ApiResponse<IEnumerable<ExpenseResponse>>> GetAllAsync(ExpenseListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var cards = await _repo.GetStatsAsync();
        return ApiResponse<IEnumerable<ExpenseResponse>>.Ok(
            data.Select(ToResponse), "Expenses retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize),
            cards);
    }

    public async Task<ApiResponse<ExpenseResponse>> GetByIdAsync(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item == null
            ? ApiResponse<ExpenseResponse>.Fail("Expense record not found.")
            : ApiResponse<ExpenseResponse>.Ok(ToResponse(item));
    }

    public async Task<ApiResponse<ExpenseResponse>> CreateAsync(CreateExpenseRequest request)
    {
        var fp = await _fundRepo.GetByIdAsync(request.FundPoolId ?? 0);
        if (fp == null) return ApiResponse<ExpenseResponse>.Fail("Fund Pool not found.");

        string campName = string.Empty;
        if (request.CampId.HasValue)
        {
            var camp = await _campRepo.GetByIdAsync(request.CampId.Value);
            if (camp == null) return ApiResponse<ExpenseResponse>.Fail("Camp not found.");
            campName = camp.Name;
        }

        var expense = new Expense
        {
            Date          = request.Date,
            Mode          = request.Mode?.Trim() ?? "",
            Head          = request.Head?.Trim() ?? "",
            FundPool      = fp.Code,
            FundPoolName  = fp.Name,
            Amount        = request.Amount,
            Nature        = request.Nature?.Trim() ?? "",
            CampId        = request.CampId,
            CampName      = campName,
            RecipientRole = request.RecipientRole?.Trim() ?? "",
            RecipientId   = request.RecipientId,
            RecipientName = request.RecipientName?.Trim() ?? "",
            Purpose       = request.Purpose?.Trim() ?? "",
        };

        var id = await _repo.CreateAsync(expense);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<ExpenseResponse>.Ok(ToResponse(created!), "Expense created successfully.");
    }

    public async Task<ApiResponse<ExpenseResponse>> UpdateAsync(int id, UpdateExpenseRequest request)
    {
        if (!await _repo.ExistsAsync(id))
            return ApiResponse<ExpenseResponse>.Fail("Expense record not found.");

        var fp = await _fundRepo.GetByIdAsync(request.FundPoolId ?? 0);
        if (fp == null) return ApiResponse<ExpenseResponse>.Fail("Fund Pool not found.");

        string campName = string.Empty;
        if (request.CampId.HasValue)
        {
            var camp = await _campRepo.GetByIdAsync(request.CampId.Value);
            if (camp == null) return ApiResponse<ExpenseResponse>.Fail("Camp not found.");
            campName = camp.Name;
        }

        await _repo.UpdateAsync(new Expense
        {
            Id            = id,
            Date          = request.Date,
            Mode          = request.Mode?.Trim() ?? "",
            Head          = request.Head?.Trim() ?? "",
            FundPool      = fp.Code,
            FundPoolName  = fp.Name,
            Amount        = request.Amount,
            Nature        = request.Nature?.Trim() ?? "",
            CampId        = request.CampId,
            CampName      = campName,
            RecipientRole = request.RecipientRole?.Trim() ?? "",
            RecipientId   = request.RecipientId,
            RecipientName = request.RecipientName?.Trim() ?? "",
            Purpose       = request.Purpose?.Trim() ?? "",
        });

        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<ExpenseResponse>.Ok(ToResponse(updated!), "Expense updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id))
            return ApiResponse<bool>.Fail("Expense record not found.");
        return await _repo.DeleteAsync(id)
            ? ApiResponse<bool>.Ok(true, "Expense deleted.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static ExpenseResponse ToResponse(Expense e) => new()
    {
        Id            = e.Id,
        ExpenseId     = e.ExpenseId,
        Date          = e.Date,
        Mode          = e.Mode,
        Head          = e.Head,
        FundPool      = e.FundPool,
        FundPoolName  = e.FundPoolName,
        Amount        = e.Amount,
        Nature        = e.Nature,
        CampId        = e.CampId,
        CampName      = e.CampName,
        RecipientRole = e.RecipientRole,
        RecipientId   = e.RecipientId,
        RecipientName = e.RecipientName,
        Purpose       = e.Purpose,
        CreatedAt     = e.CreatedAt,
        UpdatedAt     = e.UpdatedAt,
    };
}
