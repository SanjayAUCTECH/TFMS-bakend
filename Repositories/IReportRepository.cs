using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IReportRepository
{
    // Inventory Report — returns full response with rows + summary + charts
    Task<InventoryReportResponse>  GetInventoryReportAsync(ReportRequest r);
    Task<TenantReportResponse>     GetTenantReportAsync(ReportRequest r);
    Task<PartnerReportResponse>    GetPartnerReportAsync(ReportRequest r);
    Task<CampReportResponse>       GetCampReportAsync(ReportRequest r);
    Task<WaiverReportResponse>     GetWaiverReportAsync(ReportRequest r);
    Task<TransactionReportResponse>GetTransactionStatementAsync(ReportRequest r);
    Task<TenantLedgerSummary?>     GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo);
    Task<DueReportResponse>        GetDueReportAsync(ReportRequest r);

    // Room History
    Task<IEnumerable<RoomHistoryRow>> GetRoomHistoryAsync(int roomId);

    // Make Payment (outgoing)
    Task<int> MakePaymentAsync(MakePaymentRequest request);
    Task<(IEnumerable<MakePaymentResponse> Data, int Total)> GetOutgoingPaymentsAsync(ReportRequest r);
}
