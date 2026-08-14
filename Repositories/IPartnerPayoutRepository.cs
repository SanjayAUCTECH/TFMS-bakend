using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IPartnerPayoutRepository
{
    /// <summary>Get all distinct payout dates from PartnerMonthlyPayout table.</summary>
    Task<List<MonthlyPayoutDateItem>> GetMonthlyPayoutDatesAsync();

    /// <summary>Get last payout date from PartnerMonthlyCampPayout table.</summary>
    Task<LastPayoutDateResponse> GetLastPayoutDateAsync();

    /// <summary>Get last monthly payout date from PartnerMonthlyPayout table.</summary>
    Task<LastMonthlyPayoutDateResponse> GetLastMonthlyPayoutDateAsync();

    /// <summary>Get camp-wise income/expense/partner-share for a date range.</summary>
    Task<PartnerPayoutDataResponse> GetPayoutDataAsync(DateTime fromDate, DateTime toDate);

    /// <summary>Save camp-wise payout rows into PartnerMonthlyCampPayout.</summary>
    Task<int> SaveMonthlyCampPayoutAsync(SavePartnerMonthlyCampPayoutRequest request, int? userId);

    /// <summary>Get saved records from PartnerMonthlyCampPayout table.</summary>
    Task<(IEnumerable<PartnerMonthlyCampPayoutResponse> Data, int Total)>
        GetMonthlyCampPayoutAsync(GetPartnerMonthlyCampPayoutRequest request);

    /// <summary>Get partner-wise payout summary for a date range.</summary>
    Task<PartnerPayoutByMonthResponse> GetPartnerPayoutByMonthAsync(DateTime fromDate, DateTime toDate);

    /// <summary>Save partner monthly payout totals.</summary>
    Task<int> SaveMonthlyPayoutAsync(SavePartnerMonthlyPayoutRequest request, int? userId);

    /// <summary>Soft-delete partner monthly payout by month/year (optionally by partnerId).</summary>
    Task<int> DeleteMonthlyPayoutAsync(int month, int year, int? partnerId, int? deletedBy);

    /// <summary>Get PartnerMonthlyPayout records by month/year.</summary>
    Task<GetPartnerMonthlyPayoutListResponse> GetMonthlyPayoutListAsync(int month, int year, int? partnerId);

    /// <summary>Soft-delete PartnerMonthlyCampPayout by ToDate only.</summary>
    Task<int> DeleteCampPayoutAsync(DateTime toDate, int? deletedBy);

    /// <summary>Save a release payout for a partner.</summary>
    Task<int> SaveReleasePayoutAsync(CreatePartnerReleasePayoutRequest request, int? userId);
}
