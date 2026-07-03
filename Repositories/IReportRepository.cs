using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IReportRepository
{
    // Inventory Report
    Task<(IEnumerable<InventoryReportRow> Data, int Total)> GetInventoryReportAsync(ReportRequest r);

    // Tenant Report
    Task<(IEnumerable<TenantReportRow> Data, int Total)> GetTenantReportAsync(ReportRequest r);

    // Partner Report
    Task<(IEnumerable<PartnerReportRow> Data, int Total)> GetPartnerReportAsync(ReportRequest r);

    // Camp Report
    Task<(IEnumerable<CampReportRow> Data, int Total)> GetCampReportAsync(ReportRequest r);

    // Waiver Report
    Task<(IEnumerable<WaiverReportRow> Data, int Total)> GetWaiverReportAsync(ReportRequest r);

    // Tenant Ledger
    Task<TenantLedgerSummary?> GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo);

    // Transaction Statement
    Task<(IEnumerable<TransactionRow> Data, int Total)> GetTransactionStatementAsync(ReportRequest r);

    // Room History
    Task<IEnumerable<RoomHistoryRow>> GetRoomHistoryAsync(int roomId);

    // Make Payment (outgoing)
    Task<int> MakePaymentAsync(MakePaymentRequest request);
    Task<(IEnumerable<MakePaymentResponse> Data, int Total)> GetOutgoingPaymentsAsync(ReportRequest r);
}
