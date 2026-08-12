using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IPartnerPayoutRepository
{
    /// <summary>Get camp-wise income/expense/partner-share for a month.</summary>
    Task<PartnerPayoutDataResponse> GetPayoutDataAsync(int month, int year);

    /// <summary>Save camp-wise payout rows into PartnerMonthlyCampPayout.</summary>
    Task<int> SaveMonthlyCampPayoutAsync(SavePartnerMonthlyCampPayoutRequest request, int? userId);

    /// <summary>Get saved records from PartnerMonthlyCampPayout table.</summary>
    Task<(IEnumerable<PartnerMonthlyCampPayoutResponse> Data, int Total)>
        GetMonthlyCampPayoutAsync(GetPartnerMonthlyCampPayoutRequest request);

    /// <summary>Get partner-wise payout summary for a selected month.</summary>
    Task<PartnerPayoutByMonthResponse> GetPartnerPayoutByMonthAsync(int month, int year);

    /// <summary>Save partner monthly payout totals.</summary>
    Task<int> SaveMonthlyPayoutAsync(SavePartnerMonthlyPayoutRequest request, int? userId);

    /// <summary>Soft-delete partner monthly payout by month/year (optionally by partnerId).</summary>
    Task<int> DeleteMonthlyPayoutAsync(int month, int year, int? partnerId, int? deletedBy);

    /// <summary>Get PartnerMonthlyPayout records by month/year.</summary>
    Task<GetPartnerMonthlyPayoutListResponse> GetMonthlyPayoutListAsync(int month, int year, int? partnerId);

    /// <summary>Save a release payout for a partner.</summary>
    Task<int> SaveReleasePayoutAsync(CreatePartnerReleasePayoutRequest request, int? userId);
}
