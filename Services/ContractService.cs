using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class ContractService : IContractService
{
    private readonly IContractRepository  _repo;
    private readonly ITenantRepository    _tenantRepo;
    private readonly ICampRepository      _campRepo;
    private readonly IRoomRepository      _roomRepo;
    private readonly ITxnRecordRepository _txnRepo;

    public ContractService(IContractRepository repo, ITenantRepository tenantRepo,
        ICampRepository campRepo, IRoomRepository roomRepo, ITxnRecordRepository txnRepo)
    {
        _repo = repo; _tenantRepo = tenantRepo; _campRepo = campRepo;
        _roomRepo = roomRepo; _txnRepo = txnRepo;
    }

    public async Task<ApiResponse<IEnumerable<ContractResponse>>> GetAllAsync(ContractListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<ContractResponse>>.Ok(
            data.Select(ToResponse), "Contracts retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<ContractResponse>> GetByIdAsync(int id)
    {
        var c = await _repo.GetByIdAsync(id);
        return c == null ? ApiResponse<ContractResponse>.Fail("Contract not found.") : ApiResponse<ContractResponse>.Ok(ToResponse(c));
    }

    public async Task<ApiResponse<ContractResponse>> GetByContractIdAsync(string contractId)
    {
        var c = await _repo.GetByContractIdAsync(contractId);
        return c == null ? ApiResponse<ContractResponse>.Fail("Contract not found.") : ApiResponse<ContractResponse>.Ok(ToResponse(c));
    }

    public async Task<ApiResponse<ContractResponse>> CreateAsync(CreateContractRequest request)
    {
        if (request.TenantId.HasValue && request.TenantId > 0)
        {
            if (!await _tenantRepo.ExistsAsync(request.TenantId.Value))
                return ApiResponse<ContractResponse>.Fail("Tenant not found.");
        }

        // Derive primary CampId from CampIds array (first element)
        var primaryCampId = (request.CampIds != null && request.CampIds.Count > 0)
            ? request.CampIds[0]
            : 0;

        // Derive RoomIds from Rooms array if provided
        var roomIds = (request.Rooms != null && request.Rooms.Count > 0)
            ? request.Rooms.Select(r => r.RoomId).ToList()
            : new List<int>();

        var contractId = await _repo.CreateAsync(new Contract
        {
            TenantId               = request.TenantId      ?? 0,
            CampIds                = request.CampIds?.Count > 0 ? request.CampIds : new(),
            StartDate              = request.StartDate     ?? DateTime.Today,
            Months                 = request.Months        ?? 12,
            RoomIds                = roomIds,
            SecurityDeposit        = request.SecurityDeposit   ?? 0,
            ContractType           = request.ContractType  ?? "Monthly",
            InstallmentType        = request.InstallmentType   ?? "monthly",
            IssuedBy               = request.IssuedBy          ?? "",
            Notes                  = request.Notes             ?? "",
            LessorAmount           = request.LessorAmount      ?? 0,
            MonthlyTotal           = request.MonthlyTotal      ?? 0,
            ContractTotal          = request.ContractTotal     ?? 0,
            ContractPropertyUsage  = request.ContractPropertyUsage  ?? "",
            ContractBuildingName   = request.ContractBuildingName   ?? "",
            ContractPropertyType   = request.ContractPropertyType   ?? "",
            ContractLocation       = request.ContractLocation       ?? "",
            ContractPropertyNo     = request.ContractPropertyNo     ?? "",
            ContractPropertyArea   = request.ContractPropertyArea   ?? "",
            ContractPremisesNo     = request.ContractPremisesNo     ?? "",
            ContractPaymentMode    = request.ContractPaymentMode    ?? "",
            ContractPlotNo         = request.ContractPlotNo         ?? "",
            ContractMakaniNo       = request.ContractMakaniNo       ?? "",
        }, request.Rooms);

        var created = await _repo.GetByContractIdAsync(contractId);

        // ── Auto-create DR TxnRecord ──────────────────────────────────────
        if (created != null)
        {
            try
            {
                await _txnRepo.CreateAsync(new TxnRecord
                {
                    TxnType      = "DR",
                    ContractId   = created.ContractId,
                    ContractCode = created.ContractId,
                    TenantId     = created.TenantId,
                    CampId       = created.CampIds?.Count > 0 ? created.CampIds[0] : 0,
                    TotalAmount  = created.ContractTotal,
                    Amount       = created.ContractTotal,
                    TxnDate      = created.StartDate,
                    FromDate     = created.StartDate,
                    ToDate       = created.EndDate,
                    Description  = $"Contract created - {created.Months} months @ {created.MonthlyTotal}/mo",
                    ReceivedBy   = request.IssuedBy ?? "",
                });
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[ContractService] TxnRecord DR create failed: {ex.Message}");
            }
        }

        return ApiResponse<ContractResponse>.Ok(ToResponse(created!), "Contract created successfully.");
    }

    public async Task<ApiResponse<bool>> UpdateStatusAsync(string contractId, UpdateContractStatusRequest request)
    {
        var valid = new[] { "Active", "Expired", "Terminated" };
        if (string.IsNullOrEmpty(request.Status) || !valid.Contains(request.Status))
            return ApiResponse<bool>.Fail("Invalid status. Use Active, Expired, or Terminated.");
        var result = await _repo.UpdateStatusAsync(contractId, request.Status);
        return result ? ApiResponse<bool>.Ok(true, "Contract status updated.") : ApiResponse<bool>.Fail("Contract not found.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id)
    {
        var contract = await _repo.GetByIdAsync(id);
        if (contract == null) return ApiResponse<bool>.Fail("Contract not found.");
        if (contract.Status == "Active") return ApiResponse<bool>.Fail("Cannot delete an active contract.");
        return await _repo.DeleteAsync(id) ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    public async Task<ApiResponse<ContractResponse>> UpdateContractAsync(UpdateContractRequest request)
    {
        var existing = await _repo.GetByContractIdAsync(request.ContractId ?? "");
        if (existing == null) return ApiResponse<ContractResponse>.Fail("Contract not found.");
        await _repo.UpdateContractAsync(request);
        var updated = await _repo.GetByContractIdAsync(request.ContractId ?? "");
        return ApiResponse<ContractResponse>.Ok(ToResponse(updated!), "Contract updated successfully.");
    }

    public async Task<ApiResponse<ContractDocResponse>> GetDocumentAsync(string contractId)
    {
        var doc = await _repo.GetDocumentAsync(contractId);
        return doc == null
            ? ApiResponse<ContractDocResponse>.Fail("Contract not found.")
            : ApiResponse<ContractDocResponse>.Ok(doc, "Contract document retrieved.");
    }

    public async Task<ApiResponse<bool>> UpdateScheduleAsync(UpdateContractScheduleRequest request)
    {
        var contractId = request.ContractId ?? "";
        var contract = await _repo.GetByContractIdAsync(contractId);
        if (contract == null) return ApiResponse<bool>.Fail("Contract not found.");
        var scheduleJson = System.Text.Json.JsonSerializer.Serialize(
            (request.Schedule ?? new()).Select(s => new { no=s.No, amount=s.Amount, dueDate=s.DueDate, mode=s.Mode, cheque=s.Cheque, clearance=s.Clearance }));
        await _repo.UpdateScheduleAsync(contractId, scheduleJson);
        return ApiResponse<bool>.Ok(true, $"Schedule updated for {contractId}.");
    }

    private static ContractResponse ToResponse(Contract c) => new()
    {
        Id = c.Id, ContractId = c.ContractId, TenantId = c.TenantId, TenantName = c.TenantName,
        CampIds = c.CampIds?.Count > 0 ? c.CampIds : new List<int>(),
        StartDate = c.StartDate, Months = c.Months,
        EndDate = c.EndDate, MonthlyTotal = c.MonthlyTotal, ContractTotal = c.ContractTotal,
        SecurityDeposit = c.SecurityDeposit, ContractType = c.ContractType, InstallmentType = c.InstallmentType,
        IssuedBy = c.IssuedBy, Notes = c.Notes, LessorAmount = c.LessorAmount,
        Status = c.Status, CreatedAt = c.CreatedAt, UpdatedAt = c.UpdatedAt,
        Rooms = c.RoomDetails.Select(rd => new ContractRoomDetail
        {
            RoomId = rd.RoomId, CampId = rd.CampId, RoomNo = rd.RoomNo,
            MonthlyAmount = rd.MonthlyAmount, TotalAmount = rd.TotalAmount,
            PaidAmount = rd.PaidAmount, Balance = rd.Balance
        }).ToList(),
        ContractPropertyUsage = c.ContractPropertyUsage,
        ContractBuildingName  = c.ContractBuildingName,
        ContractPropertyType  = c.ContractPropertyType,
        ContractLocation      = c.ContractLocation,
        ContractPropertyNo    = c.ContractPropertyNo,
        ContractPropertyArea  = c.ContractPropertyArea,
        ContractPremisesNo    = c.ContractPremisesNo,
        ContractPaymentMode   = c.ContractPaymentMode,
        ContractPlotNo        = c.ContractPlotNo,
        ContractMakaniNo      = c.ContractMakaniNo,
        TotalPaid = c.TotalPaid,
        TotalDue  = c.TotalDue,
        LastPaymentAmount = c.LastPaymentAmount,
        LastPaymentDate   = c.LastPaymentDate?.ToString("yyyy-MM-dd"),
        Payments = c.Payments.Select(p => new ContractPaymentResponse
        {
            Id = p.Id, InstallmentNo = p.InstallmentNo, Amount = p.Amount,
            DueDate = p.DueDate, PaidAmount = p.PaidAmount, PaidDate = p.PaidDate,
            Status = p.Status, PaymentMode = p.PaymentMode,
            ChequeNumber  = p.ChequeNumber,
            ClearanceDate = p.ClearanceDate,
        }).ToList(),
    };
}
