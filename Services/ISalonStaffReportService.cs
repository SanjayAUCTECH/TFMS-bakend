using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonStaffReportService
{
    Task<ApiResponse<IEnumerable<SalonStaffReportRow>>> GetReportAsync(SalonStaffReportRequest request);
}
