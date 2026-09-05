using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ISalonExpenseReportRepository
{
    Task<(IEnumerable<SalonExpenseReportRow> Data, int Total)> GetReportAsync(SalonExpenseReportRequest request);
    Task<SalonExpenseReportCards>                              GetCardsAsync(string? dateFrom, string? dateTo, string? head);
}
