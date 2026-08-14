using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class PartnerPayoutService : IPartnerPayoutService
{
    private readonly IPartnerPayoutRepository _repo;

    public PartnerPayoutService(IPartnerPayoutRepository repo) => _repo = repo;

    // ── GET all monthly payout dates ──────────────────────────────
    public async Task<ApiResponse<List<MonthlyPayoutDateItem>>> GetMonthlyPayoutDatesAsync()
    {
        var data = await _repo.GetMonthlyPayoutDatesAsync();
        return ApiResponse<List<MonthlyPayoutDateItem>>.Ok(
            data, $"{data.Count} payout period(s) found.");
    }

    // ── GET last payout date (PartnerMonthlyCampPayout) ──────────
    public async Task<ApiResponse<LastPayoutDateResponse>> GetLastPayoutDateAsync()
    {
        var data = await _repo.GetLastPayoutDateAsync();
        return ApiResponse<LastPayoutDateResponse>.Ok(data, "Last payout date retrieved successfully.");
    }

    // ── GET last monthly payout date (PartnerMonthlyPayout) ──────
    public async Task<ApiResponse<LastMonthlyPayoutDateResponse>> GetLastMonthlyPayoutDateAsync()
    {
        var data = await _repo.GetLastMonthlyPayoutDateAsync();
        return ApiResponse<LastMonthlyPayoutDateResponse>.Ok(data, "Last monthly payout date retrieved successfully.");
    }

    // ── GET payout data ───────────────────────────────────────────
    public async Task<ApiResponse<PartnerPayoutDataResponse>> GetPayoutDataAsync(DateTime fromDate, DateTime toDate)
    {
        if (fromDate == default)
            return ApiResponse<PartnerPayoutDataResponse>.Fail("FromDate is required.");
        if (toDate == default)
            return ApiResponse<PartnerPayoutDataResponse>.Fail("ToDate is required.");
        if (fromDate > toDate)
            return ApiResponse<PartnerPayoutDataResponse>.Fail("FromDate cannot be greater than ToDate.");

        var data = await _repo.GetPayoutDataAsync(fromDate, toDate);
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

    // ── GET partner payout by date range ─────────────────────────
    public async Task<ApiResponse<PartnerPayoutByMonthResponse>> GetPartnerPayoutByMonthAsync(DateTime fromDate, DateTime toDate)
    {
        if (fromDate == default)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail("FromDate is required.");
        if (toDate == default)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail("ToDate is required.");
        if (fromDate > toDate)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail("FromDate cannot be greater than ToDate.");

        var data = await _repo.GetPartnerPayoutByMonthAsync(fromDate, toDate);

        if (data.Partners.Count == 0)
            return ApiResponse<PartnerPayoutByMonthResponse>.Fail(
                $"No payout data found for {data.PeriodLabel}. Please generate camp payout first.");

        return ApiResponse<PartnerPayoutByMonthResponse>.Ok(
            data, $"Partner payout data for {data.PeriodLabel} retrieved successfully.");
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
    public async Task<ApiResponse<IEnumerable<PartnerMonthlyPayoutResponse>>> GetMonthlyPayoutListAsync(
        GetPartnerMonthlyPayoutListRequest request)
    {
        var (data, total) = await _repo.GetMonthlyPayoutListAsync(request);
        return ApiResponse<IEnumerable<PartnerMonthlyPayoutResponse>>.Ok(
            data,
            "Records retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize)
        );
    }

    // ── DELETE PartnerMonthlyCampPayout by ToDate only ────────────
    public async Task<ApiResponse<DeletePartnerCampPayoutResponse>> DeleteCampPayoutAsync(
        DeletePartnerCampPayoutRequest request, int? userId)
    {
        if (request.ToDate == default)
            return ApiResponse<DeletePartnerCampPayoutResponse>.Fail("ToDate is required.");

        var label = $"{request.ToDate:dd MMM yyyy}";
        var deletedCount = await _repo.DeleteCampPayoutAsync(request.ToDate, userId);

        return ApiResponse<DeletePartnerCampPayoutResponse>.Ok(
            new DeletePartnerCampPayoutResponse
            {
                DeletedCount = deletedCount,
                PeriodLabel  = label,
            },
            deletedCount > 0
                ? $"{deletedCount} camp payout records deleted for ToDate {label}."
                : $"No records found for ToDate {label}. Nothing to delete.");
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
