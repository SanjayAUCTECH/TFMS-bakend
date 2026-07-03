using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IReportService
{
    Task<ApiResponse<IEnumerable<InventoryReportRow>>>  GetInventoryReportAsync(ReportRequest request);
    Task<ApiResponse<IEnumerable<TenantReportRow>>>     GetTenantReportAsync(ReportRequest request);
    Task<ApiResponse<IEnumerable<PartnerReportRow>>>    GetPartnerReportAsync(ReportRequest request);
    Task<ApiResponse<IEnumerable<CampReportRow>>>       GetCampReportAsync(ReportRequest request);
    Task<ApiResponse<IEnumerable<WaiverReportRow>>>     GetWaiverReportAsync(ReportRequest request);
    Task<ApiResponse<TenantLedgerSummary>>              GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo);
    Task<ApiResponse<IEnumerable<TransactionRow>>>      GetTransactionStatementAsync(ReportRequest request);
    Task<ApiResponse<IEnumerable<RoomHistoryRow>>>      GetRoomHistoryAsync(int roomId);
    Task<ApiResponse<MakePaymentResponse>>              MakePaymentAsync(MakePaymentRequest request);
    Task<ApiResponse<IEnumerable<MakePaymentResponse>>> GetOutgoingPaymentsAsync(ReportRequest request);
}
