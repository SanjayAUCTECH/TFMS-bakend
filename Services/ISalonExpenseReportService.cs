using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonExpenseReportService
{
    Task<ApiResponse<IEnumerable<SalonExpenseReportRow>>> GetReportAsync(SalonExpenseReportRequest request);
}
