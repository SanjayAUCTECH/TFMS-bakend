using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class MisService : IMisService
{
    private readonly IMisRepository _repo;
    public MisService(IMisRepository repo) => _repo = repo;

    public async Task<ApiResponse<MisStatsResponse>> GetMisStatsAsync(MisRequest request)
    {
        var result = await _repo.GetMisStatsAsync(request);
        return ApiResponse<MisStatsResponse>.Ok(result, "MIS stats retrieved.");
    }

    public async Task<ApiResponse<IEnumerable<OwnerReportRow>>> GetOwnerReportAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetOwnerReportAsync(request);
        return ApiResponse<IEnumerable<OwnerReportRow>>.Ok(data, "Owner report retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }
}
