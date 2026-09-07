using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ISalonStaffReportRepository
{
    Task<(IEnumerable<SalonStaffReportRow> Data, int Total, SalonStaffReportCards Cards)> GetReportAsync(SalonStaffReportRequest request);
}
