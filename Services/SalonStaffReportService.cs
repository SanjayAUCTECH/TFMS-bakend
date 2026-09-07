using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonStaffReportService : ISalonStaffReportService
{
    private readonly ISalonStaffReportRepository _repo;
    public SalonStaffReportService(ISalonStaffReportRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<SalonStaffReportRow>>> GetReportAsync(
        SalonStaffReportRequest request)
    {
        var (data, total, cards) = await _repo.GetReportAsync(request);

        return ApiResponse<IEnumerable<SalonStaffReportRow>>.Ok(
            data,
            "Salon staff report retrieved successfully.",
            PaginationHelper.Build(total, 1, total == 0 ? 1 : total),
            cards
        );
    }
}
