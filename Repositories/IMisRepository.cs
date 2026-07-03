using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IMisRepository
{
    Task<MisStatsResponse>                              GetMisStatsAsync(MisRequest request);
    Task<(IEnumerable<OwnerReportRow> Data, int Total)> GetOwnerReportAsync(ReportRequest request);
}
