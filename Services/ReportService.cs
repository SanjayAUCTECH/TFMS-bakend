using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class ReportService : IReportService
{
    private readonly IReportRepository _repo;
    public ReportService(IReportRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<InventoryReportRow>>> GetInventoryReportAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetInventoryReportAsync(request);
        return ApiResponse<IEnumerable<InventoryReportRow>>.Ok(data, "Inventory report retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<TenantReportRow>>> GetTenantReportAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetTenantReportAsync(request);
        return ApiResponse<IEnumerable<TenantReportRow>>.Ok(data, "Tenant report retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<PartnerReportRow>>> GetPartnerReportAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetPartnerReportAsync(request);
        return ApiResponse<IEnumerable<PartnerReportRow>>.Ok(data, "Partner report retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<CampReportRow>>> GetCampReportAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetCampReportAsync(request);
        return ApiResponse<IEnumerable<CampReportRow>>.Ok(data, "Camp report retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<WaiverReportRow>>> GetWaiverReportAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetWaiverReportAsync(request);
        return ApiResponse<IEnumerable<WaiverReportRow>>.Ok(data, "Waiver report retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<TenantLedgerSummary>> GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo)
    {
        var result = await _repo.GetTenantLedgerAsync(tenantId, contractId, dateFrom, dateTo);
        return result == null
            ? ApiResponse<TenantLedgerSummary>.Fail("No ledger data found for this tenant.")
            : ApiResponse<TenantLedgerSummary>.Ok(result, "Tenant ledger retrieved.");
    }

    public async Task<ApiResponse<IEnumerable<TransactionRow>>> GetTransactionStatementAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetTransactionStatementAsync(request);
        return ApiResponse<IEnumerable<TransactionRow>>.Ok(data, "Transaction statement retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<IEnumerable<RoomHistoryRow>>> GetRoomHistoryAsync(int roomId)
    {
        var data = await _repo.GetRoomHistoryAsync(roomId);
        return ApiResponse<IEnumerable<RoomHistoryRow>>.Ok(data, "Room history retrieved.");
    }

    public async Task<ApiResponse<MakePaymentResponse>> MakePaymentAsync(MakePaymentRequest request)
    {
        var id = await _repo.MakePaymentAsync(request);
        var payments = await _repo.GetOutgoingPaymentsAsync(new ReportRequest { PageNumber = 1, PageSize = 1 });
        var created  = payments.Data.FirstOrDefault(p => p.Id == id);
        return created != null
            ? ApiResponse<MakePaymentResponse>.Ok(created, "Payment made successfully.")
            : ApiResponse<MakePaymentResponse>.Fail("Payment saved but could not retrieve details.");
    }

    public async Task<ApiResponse<IEnumerable<MakePaymentResponse>>> GetOutgoingPaymentsAsync(ReportRequest request)
    {
        var (data, total) = await _repo.GetOutgoingPaymentsAsync(request);
        return ApiResponse<IEnumerable<MakePaymentResponse>>.Ok(data, "Outgoing payments retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize));
    }
}
