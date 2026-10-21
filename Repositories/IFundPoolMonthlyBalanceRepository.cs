using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IFundPoolMonthlyBalanceRepository
{
    Task<IEnumerable<FundPoolMonthlyBalance>> SaveMonthlyBalanceAsync(int reportMonth, int reportYear, DateTime? reportDate, int? userId, List<FundPoolMonthlyBalanceItem> fundPools);
    Task<(IEnumerable<FundPoolMonthlyBalance> Data, FundPoolMonthlyBalanceTotals Totals)> GetMonthlyBalanceAsync(int reportMonth, int reportYear);
    Task<(IEnumerable<FundPoolMonthlyBalanceSummaryResponse> Data, int TotalRecords)> GetAllMonthlyBalancesAsync(FundPoolMonthlyBalanceListRequest request);
    Task<int> DeleteMonthlyBalanceAsync(int reportMonth, int reportYear, int? userId);
}
