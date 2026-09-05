using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonExpenseReportService : ISalonExpenseReportService
{
    private readonly ISalonExpenseReportRepository _repo;
    public SalonExpenseReportService(ISalonExpenseReportRepository repo) => _repo = repo;

    // Cards data same filters se fetch hoga aur response ke 'cards' field mein aayega
    public async Task<ApiResponse<IEnumerable<SalonExpenseReportRow>>> GetReportAsync(
        SalonExpenseReportRequest request)
    {
        // Fetch detail rows + cards parallel
        var rowsTask  = _repo.GetReportAsync(request);
        var cardsTask = _repo.GetCardsAsync(request.DateFrom, request.DateTo, request.Head);

        await Task.WhenAll(rowsTask, cardsTask);

        var (data, total) = rowsTask.Result;
        var cards         = cardsTask.Result;

        return ApiResponse<IEnumerable<SalonExpenseReportRow>>.Ok(
            data,
            "Salon expense report retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize),
            cards   // ← cards embedded in same response
        );
    }
}
