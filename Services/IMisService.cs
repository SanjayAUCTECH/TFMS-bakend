using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IMisService
{
    Task<ApiResponse<MisStatsResponse>>              GetMisStatsAsync(MisRequest request);
    Task<ApiResponse<IEnumerable<OwnerReportRow>>>   GetOwnerReportAsync(ReportRequest request);
}
