using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class PartnerPayoutService : IPartnerPayoutService
{
    private readonly IPartnerPayoutRepository _repo;

    public PartnerPayoutService(IPartnerPayoutRepository repo) => _repo = repo;

    // ── GET payout data ───────────────────────────────────────────
    public async Task<ApiResponse<PartnerPayoutDataResponse>> GetPayoutDataAsync(int month, int year)
    {
        if (month < 1 || month > 12)
            return ApiResponse<PartnerPayoutDataResponse>.Fail("Month must be between 1 and 12.");
        if (year < 2000 || year > 2100)
            return ApiResponse<PartnerPayoutDataResponse>.Fail("Invalid year.");

        var data = await _repo.GetPayoutDataAsync(month, year);
        return ApiResponse<PartnerPayoutDataResponse>.Ok(data, "Partner payout data retrieved successfully.");
    }

    // ── SAVE monthly camp payout ──────────────────────────────────
    public async Task<ApiResponse<SavePartnerMonthlyCampPayoutResponse>> SaveMonthlyCampPayoutAsync(
        SavePartnerMonthlyCampPayoutRequest request, int? userId)
    {
        if (request.Rows == null || request.Rows.Count == 0)
            return ApiResponse<SavePartnerMonthlyCampPayoutResponse>.Fail("No rows to save.");

        if (request.FromDate == default || request.ToDate == default)
            return ApiResponse<SavePartnerMonthlyCampPayoutResponse>.Fail("FromDate and ToDate are required.");

        if (request.FromDate > request.ToDate)
            return ApiResponse<SavePartnerMonthlyCampPayoutResponse>.Fail("FromDate cannot be greater than ToDate.");

        var savedCount = await _repo.SaveMonthlyCampPayoutAsync(request, userId);

        return ApiResponse<SavePartnerMonthlyCampPayoutResponse>.Ok(
            new SavePartnerMonthlyCampPayoutResponse
            {
                SavedCount = savedCount,
                FromDate   = request.FromDate,
                ToDate     = request.ToDate,
            },
            $"{savedCount} records saved successfully."
        );
    }

    // ── GET saved monthly camp payout ─────────────────────────────
    public async Task<ApiResponse<IEnumerable<PartnerMonthlyCampPayoutResponse>>>
        GetMonthlyCampPayoutAsync(GetPartnerMonthlyCampPayoutRequest request)
    {
        var (data, total) = await _repo.GetMonthlyCampPayoutAsync(request);
        return ApiResponse<IEnumerable<PartnerMonthlyCampPayoutResponse>>.Ok(
            data,
            "Records retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize)
        );
    }

    // ── GET partner payout by month ───────────────────────────────
    public async Task<ApiResponse<PartnerPayoutByMonthResponse>> GetPartnerPayoutByMonthAsync(int month, int year)
    {
        if (month < 1 || month > 12)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail("Month must be between 1 and 12.");
        if (year < 2000 || year > 2100)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail("Invalid year.");

        var data = await _repo.GetPartnerPayoutByMonthAsync(month, year);

        if (data.Partners.Count == 0)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail(
                $"No payout data found for {data.MonthLabel}. Please generate camp payout first.");

        return ApiResponse<PartnerPayoutByMonthResponse>.Ok(
            data, $"Partner payout data for {data.MonthLabel} retrieved successfully.");
    }

    // ── SAVE PartnerMonthlyPayout ─────────────────────────────────
    public async Task<ApiResponse<SavePartnerMonthlyPayoutResponse>> SaveMonthlyPayoutAsync(
        SavePartnerMonthlyPayoutRequest request, int? userId)
    {
        if (request.Rows == null || request.Rows.Count == 0)
            return ApiResponse<SavePartnerMonthlyPayoutResponse>.Fail("No rows to save.");
        if (request.FromDate == default || request.ToDate == default)
            return ApiResponse<SavePartnerMonthlyPayoutResponse>.Fail("FromDate and ToDate are required.");
        if (request.FromDate > request.ToDate)
            return ApiResponse<SavePartnerMonthlyPayoutResponse>.Fail("FromDate cannot be greater than ToDate.");

        var savedCount = await _repo.SaveMonthlyPayoutAsync(request, userId);
        return ApiResponse<SavePartnerMonthlyPayoutResponse>.Ok(
            new SavePartnerMonthlyPayoutResponse
            {
                SavedCount = savedCount,
                FromDate   = request.FromDate,
                ToDate     = request.ToDate,
            },
            $"{savedCount} partner payout records saved successfully.");
    }

    // ── DELETE PartnerMonthlyPayout by month ──────────────────────
    public async Task<ApiResponse<DeletePartnerMonthlyPayoutResponse>> DeleteMonthlyPayoutAsync(
        DeletePartnerMonthlyPayoutRequest request, int? userId)
    {
        if (request.Month < 1 || request.Month > 12)
            return ApiResponse<DeletePartnerMonthlyPayoutResponse>.Fail("Month must be between 1 and 12.");
        if (request.Year < 2000 || request.Year > 2100)
            return ApiResponse<DeletePartnerMonthlyPayoutResponse>.Fail("Invalid year.");

        var monthLabel = new DateTime(request.Year, request.Month, 1).ToString("MMMM yyyy");
        var deletedCount = await _repo.DeleteMonthlyPayoutAsync(
            request.Month, request.Year, request.PartnerId, userId);

        if (deletedCount == 0)
            return ApiResponse<DeletePartnerMonthlyPayoutResponse>.Fail(
                $"No records found for {monthLabel} to delete.");

        return ApiResponse<DeletePartnerMonthlyPayoutResponse>.Ok(
            new DeletePartnerMonthlyPayoutResponse
            {
                DeletedCount = deletedCount,
                MonthLabel   = monthLabel,
            },
            $"{deletedCount} records deleted for {monthLabel}.");
    }

    // ── GET PartnerMonthlyPayout list ─────────────────────────────
    public async Task<ApiResponse<GetPartnerMonthlyPayoutListResponse>> GetMonthlyPayoutListAsync(
        int month, int year, int? partnerId)
    {
        if (month < 1 || month > 12)
            return ApiResponse<GetPartnerMonthlyPayoutListResponse>.Fail("Month must be between 1 and 12.");
        if (year < 2000 || year > 2100)
            return ApiResponse<GetPartnerMonthlyPayoutListResponse>.Fail("Invalid year.");

        var data = await _repo.GetMonthlyPayoutListAsync(month, year, partnerId);

        if (data.Partners.Count == 0)
            return ApiResponse<GetPartnerMonthlyPayoutListResponse>.Fail(
                $"No monthly payout data found for {data.MonthLabel}.");

        return ApiResponse<GetPartnerMonthlyPayoutListResponse>.Ok(
            data, $"Partner monthly payout for {data.MonthLabel} retrieved successfully.");
    }

    // ── SAVE PartnerReleasePayout ─────────────────────────────────
    public async Task<ApiResponse<PartnerReleasePayoutResponse>> SaveReleasePayoutAsync(
        CreatePartnerReleasePayoutRequest request, int? userId)
    {
        if (request.PartnerId <= 0)
            return ApiResponse<PartnerReleasePayoutResponse>.Fail("Valid PartnerId is required.");
        if (request.ReleaseAmount <= 0)
            return ApiResponse<PartnerReleasePayoutResponse>.Fail("Release amount must be greater than 0.");
        if (request.ReleaseDate == default)
            return ApiResponse<PartnerReleasePayoutResponse>.Fail("Release date is required.");

        var newId = await _repo.SaveReleasePayoutAsync(request, userId);

        return ApiResponse<PartnerReleasePayoutResponse>.Ok(
            new PartnerReleasePayoutResponse
            {
                Id                    = newId,
                Date                  = request.Date == default ? DateTime.Now : request.Date,
                ReleaseDate           = request.ReleaseDate,
                PartnerId             = request.PartnerId,
                CampPartnerPercentage = request.CampPartnerPercentage,
                TotalCampIncome       = request.TotalCampIncome,
                TotalCampExpense      = request.TotalCampExpense,
                TotalHOExpense        = request.TotalHOExpense,
                TotalAllExpense       = request.TotalAllExpense,
                TotalBenefitAmount    = request.TotalBenefitAmount,
                PartnerShareAmount    = request.PartnerShareAmount,
                ReleaseAmount         = request.ReleaseAmount,
                BalanceAmount         = request.BalanceAmount,
                CreatedAt             = DateTime.Now,
            },
            "Partner release payout saved successfully.");
    }
}
