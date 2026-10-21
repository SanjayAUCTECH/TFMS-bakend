using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class FundPoolMonthlyBalanceService : IFundPoolMonthlyBalanceService
{
    private readonly IFundPoolMonthlyBalanceRepository _repo;
    public FundPoolMonthlyBalanceService(IFundPoolMonthlyBalanceRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<FundPoolMonthlyBalanceResponse>>> SaveMonthlyBalanceAsync(
        SaveFundPoolMonthlyBalanceRequest request, int? userId)
    {
        if (request.ReportMonth < 1 || request.ReportMonth > 12)
            return ApiResponse<IEnumerable<FundPoolMonthlyBalanceResponse>>.Fail("Invalid month. Must be between 1 and 12.");

        if (request.ReportYear < 2020 || request.ReportYear > 2100)
            return ApiResponse<IEnumerable<FundPoolMonthlyBalanceResponse>>.Fail("Invalid year.");

        if (request.FundPools == null || request.FundPools.Count == 0)
            return ApiResponse<IEnumerable<FundPoolMonthlyBalanceResponse>>.Fail("Fund pool data is required.");

        var data = await _repo.SaveMonthlyBalanceAsync(
            request.ReportMonth, 
            request.ReportYear, 
            request.ReportDate, 
            userId,
            request.FundPools);

        var response = data.Select(ToResponse);
        return ApiResponse<IEnumerable<FundPoolMonthlyBalanceResponse>>.Ok(
            response, "Fund Pool monthly balance saved successfully.");
    }

    public async Task<ApiResponse<object>> GetMonthlyBalanceAsync(GetFundPoolMonthlyBalanceRequest request)
    {
        var (data, totals) = await _repo.GetMonthlyBalanceAsync(request.ReportMonth, request.ReportYear);
        
        var response = new
        {
            data = data.Select(ToResponse),
            totals = new
            {
                totalCurrentFundPool = totals.TotalCurrentFundPool,
                totalBufferFundPool = totals.TotalBufferFundPool,
                netTotal = totals.NetTotal
            }
        };

        return ApiResponse<object>.Ok(response, "Fund Pool monthly balance retrieved successfully.");
    }

    public async Task<ApiResponse<IEnumerable<FundPoolMonthlyBalanceSummaryResponse>>> GetAllMonthlyBalancesAsync(
        FundPoolMonthlyBalanceListRequest request)
    {
        var (data, total) = await _repo.GetAllMonthlyBalancesAsync(request);
        
        return ApiResponse<IEnumerable<FundPoolMonthlyBalanceSummaryResponse>>.Ok(
            data, "Fund Pool monthly balances retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<bool>> DeleteMonthlyBalanceAsync(
        DeleteFundPoolMonthlyBalanceRequest request, int? userId)
    {
        var deletedCount = await _repo.DeleteMonthlyBalanceAsync(request.ReportMonth, request.ReportYear, userId);
        
        if (deletedCount > 0)
            return ApiResponse<bool>.Ok(true, $"Fund Pool monthly balance deleted successfully. ({deletedCount} records deleted)");
        
        return ApiResponse<bool>.Fail("No records found to delete.");
    }

    private static FundPoolMonthlyBalanceResponse ToResponse(FundPoolMonthlyBalance b) => new()
    {
        Id = b.Id,
        FundPoolId = b.FundPoolId,
        FundPoolName = b.FundPoolName,
        ReportMonth = b.ReportMonth,
        ReportYear = b.ReportYear,
        ReportDate = b.ReportDate,
        CurrentFundPool = b.CurrentFundPool,
        BufferFundPool = b.BufferFundPool,
        TotalFundPool = b.TotalFundPool,
        Status = b.Status,
        CreatedAt = b.CreatedAt,
        UpdatedAt = b.UpdatedAt,
    };
}
