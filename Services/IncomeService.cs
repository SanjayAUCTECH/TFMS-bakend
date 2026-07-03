using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class IncomeService : IIncomeService
{
    private readonly IIncomeRepository   _repo;
    private readonly IFundPoolRepository _fundRepo;

    public IncomeService(IIncomeRepository repo, IFundPoolRepository fundRepo)
    {
        _repo = repo; _fundRepo = fundRepo;
    }

    public async Task<ApiResponse<IEnumerable<IncomeResponse>>> GetAllAsync(IncomeListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<IncomeResponse>>.Ok(
            data.Select(ToResponse), "Incomes retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IncomeResponse>> GetByIdAsync(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item == null
            ? ApiResponse<IncomeResponse>.Fail("Income record not found.")
            : ApiResponse<IncomeResponse>.Ok(ToResponse(item));
    }

    public async Task<ApiResponse<IncomeResponse>> CreateAsync(CreateIncomeRequest request)
    {
        var fp = await _fundRepo.GetByIdAsync(request.FundPoolId);
        if (fp == null) return ApiResponse<IncomeResponse>.Fail("Fund Pool not found.");

        var income = new Income
        {
            Date         = request.Date,
            Mode         = request.Mode.Trim(),
            Head         = request.Head.Trim(),
            FundPool     = fp.Code,
            FundPoolName = fp.Name,
            Amount       = request.Amount,
            Purpose      = request.Purpose.Trim(),
            Source       = request.Source.Trim(),
            SourceRef    = request.SourceRef.Trim(),
        };

        var id = await _repo.CreateAsync(income);
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<IncomeResponse>.Ok(ToResponse(created!), "Income created successfully.");
    }

    public async Task<ApiResponse<IncomeResponse>> UpdateAsync(int id, UpdateIncomeRequest request)
    {
        if (!await _repo.ExistsAsync(id))
            return ApiResponse<IncomeResponse>.Fail("Income record not found.");

        var fp = await _fundRepo.GetByIdAsync(request.FundPoolId);
        if (fp == null) return ApiResponse<IncomeResponse>.Fail("Fund Pool not found.");

        await _repo.UpdateAsync(new Income
        {
            Id           = id,
            Date         = request.Date,
            Mode         = request.Mode.Trim(),
            Head         = request.Head.Trim(),
            FundPool     = fp.Code,
            FundPoolName = fp.Name,
            Amount       = request.Amount,
            Purpose      = request.Purpose.Trim(),
            Source       = request.Source.Trim(),
            SourceRef    = request.SourceRef.Trim(),
        });

        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<IncomeResponse>.Ok(ToResponse(updated!), "Income updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        if (!await _repo.ExistsAsync(id))
            return ApiResponse<bool>.Fail("Income record not found.");
        return await _repo.DeleteAsync(id)
            ? ApiResponse<bool>.Ok(true, "Income deleted.")
            : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static IncomeResponse ToResponse(Income i) => new()
    {
        Id           = i.Id,
        IncomeId     = i.IncomeId,
        Date         = i.Date,
        Mode         = i.Mode,
        Head         = i.Head,
        FundPool     = i.FundPool,
        FundPoolName = i.FundPoolName,
        Amount       = i.Amount,
        Purpose      = i.Purpose,
        Source       = i.Source,
        SourceRef    = i.SourceRef,
        CreatedAt    = i.CreatedAt,
        UpdatedAt    = i.UpdatedAt,
    };
}
