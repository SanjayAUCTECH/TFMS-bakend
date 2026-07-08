using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class ReportService : IReportService
{
    private readonly IReportRepository _repo;
    public ReportService(IReportRepository repo) => _repo = repo;

    public async Task<ApiResponse<InventoryReportResponse>> GetInventoryReportAsync(ReportRequest request)
    {
        var result = await _repo.GetInventoryReportAsync(request);
        return ApiResponse<InventoryReportResponse>.Ok(result, "Inventory report retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<TenantReportResponse>> GetTenantReportAsync(ReportRequest request)
    {
        var result = await _repo.GetTenantReportAsync(request);
        return ApiResponse<TenantReportResponse>.Ok(result, "Tenant report retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<PartnerReportResponse>> GetPartnerReportAsync(ReportRequest request)
    {
        var result = await _repo.GetPartnerReportAsync(request);
        return ApiResponse<PartnerReportResponse>.Ok(result, "Partner report retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<CampReportResponse>> GetCampReportAsync(ReportRequest request)
    {
        var result = await _repo.GetCampReportAsync(request);
        return ApiResponse<CampReportResponse>.Ok(result, "Camp report retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<WaiverReportResponse>> GetWaiverReportAsync(ReportRequest request)
    {
        var result = await _repo.GetWaiverReportAsync(request);
        return ApiResponse<WaiverReportResponse>.Ok(result, "Waiver report retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<TransactionReportResponse>> GetTransactionStatementAsync(ReportRequest request)
    {
        var result = await _repo.GetTransactionStatementAsync(request);
        return ApiResponse<TransactionReportResponse>.Ok(result, "Transaction statement retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<DueReportResponse>> GetDueReportAsync(ReportRequest request)
    {
        var result = await _repo.GetDueReportAsync(request);
        return ApiResponse<DueReportResponse>.Ok(result, "Due report retrieved.",
            PaginationHelper.Build(result.TotalRecords, request.ResolvedPage, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<TenantLedgerSummary>> GetTenantLedgerAsync(int tenantId, string? contractId, string? dateFrom, string? dateTo)
    {
        var result = await _repo.GetTenantLedgerAsync(tenantId, contractId, dateFrom, dateTo);
        return result == null
            ? ApiResponse<TenantLedgerSummary>.Fail("No ledger data found for this tenant.")
            : ApiResponse<TenantLedgerSummary>.Ok(result, "Tenant ledger retrieved.");
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
