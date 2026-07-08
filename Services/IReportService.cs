using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IReportService
{
    Task<ApiResponse<InventoryReportResponse>>    GetInventoryReportAsync(ReportRequest request);
    Task<ApiResponse<TenantReportResponse>>       GetTenantReportAsync(ReportRequest request);
    Task<ApiResponse<PartnerReportResponse>>      GetPartnerReportAsync(ReportRequest request);
    Task<ApiResponse<CampReportResponse>>         GetCampReportAsync(ReportRequest request);
    Task<ApiResponse<WaiverReportResponse>>       GetWaiverReportAsync(ReportRequest request);
    Task<ApiResponse<TransactionReportResponse>>  GetTransactionStatementAsync(ReportRequest request);
    Task<ApiResponse<TenantLedgerSummary>>        GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo);
    Task<ApiResponse<DueReportResponse>>          GetDueReportAsync(ReportRequest request);
    Task<ApiResponse<IEnumerable<RoomHistoryRow>>>      GetRoomHistoryAsync(int roomId);
    Task<ApiResponse<MakePaymentResponse>>              MakePaymentAsync(MakePaymentRequest request);
    Task<ApiResponse<IEnumerable<MakePaymentResponse>>> GetOutgoingPaymentsAsync(ReportRequest request);
}
