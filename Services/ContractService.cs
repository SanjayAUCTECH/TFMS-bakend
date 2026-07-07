using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class ContractService : IContractService
{
    private readonly IContractRepository _repo;
    private readonly ITenantRepository   _tenantRepo;
    private readonly ICampRepository     _campRepo;
    private readonly IRoomRepository     _roomRepo;

    public ContractService(IContractRepository repo, ITenantRepository tenantRepo,
        ICampRepository campRepo, IRoomRepository roomRepo)
    {
        _repo = repo; _tenantRepo = tenantRepo; _campRepo = campRepo; _roomRepo = roomRepo;
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
        if (!await _tenantRepo.ExistsAsync(request.TenantId))
            return ApiResponse<ContractResponse>.Fail("Tenant not found.");
        if (await _campRepo.GetByIdAsync(request.CampId) == null)
            return ApiResponse<ContractResponse>.Fail("Camp not found.");
        if (request.RoomIds == null || request.RoomIds.Count == 0)
            return ApiResponse<ContractResponse>.Fail("At least one room must be selected.");

        var contractId = await _repo.CreateAsync(new Contract
        {
            TenantId        = request.TenantId,
            CampId          = request.CampId,
            StartDate       = request.StartDate,
            Months          = request.Months,
            RoomIds         = request.RoomIds,
            SecurityDeposit = request.SecurityDeposit,
            InstallmentType = request.InstallmentType,
            IssuedBy        = request.IssuedBy,
            Notes           = request.Notes,
            LessorAmount    = request.LessorAmount,
        });
        var created = await _repo.GetByContractIdAsync(contractId);
        return ApiResponse<ContractResponse>.Ok(ToResponse(created!), "Contract created successfully.");
    }

    public async Task<ApiResponse<bool>> UpdateStatusAsync(string contractId, UpdateContractStatusRequest request)
    {
        var valid = new[] { "Active", "Expired", "Terminated" };
        if (!valid.Contains(request.Status))
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
        var existing = await _repo.GetByContractIdAsync(request.ContractId);
        if (existing == null) return ApiResponse<ContractResponse>.Fail("Contract not found.");
        if (request.RoomIds == null || request.RoomIds.Count == 0)
            return ApiResponse<ContractResponse>.Fail("At least one room must be selected.");
        await _repo.UpdateContractAsync(request);
        var updated = await _repo.GetByContractIdAsync(request.ContractId);
        return ApiResponse<ContractResponse>.Ok(ToResponse(updated!), "Contract updated successfully.");
    }

    public async Task<ApiResponse<bool>> UpdateScheduleAsync(UpdateContractScheduleRequest request)
    {
        var contract = await _repo.GetByContractIdAsync(request.ContractId);
        if (contract == null) return ApiResponse<bool>.Fail("Contract not found.");
        var scheduleJson = System.Text.Json.JsonSerializer.Serialize(
            request.Schedule.Select(s => new
            {
                no        = s.No,
                amount    = s.Amount,
                dueDate   = s.DueDate,
                mode      = s.Mode,
                cheque    = s.Cheque,
                clearance = s.Clearance,
            }));
        await _repo.UpdateScheduleAsync(request.ContractId, scheduleJson);
        return ApiResponse<bool>.Ok(true, $"Schedule updated for {request.ContractId}.");
    }

    private static ContractResponse ToResponse(Contract c) => new()
    {
        Id = c.Id, ContractId = c.ContractId, TenantId = c.TenantId, TenantName = c.TenantName,
        CampId = c.CampId, CampName = c.CampName, StartDate = c.StartDate, Months = c.Months,
        EndDate = c.EndDate, MonthlyTotal = c.MonthlyTotal, ContractTotal = c.ContractTotal,
        SecurityDeposit = c.SecurityDeposit, InstallmentType = c.InstallmentType,
        IssuedBy = c.IssuedBy, Notes = c.Notes, LessorAmount = c.LessorAmount,
        Status = c.Status, RoomIds = c.RoomIds, CreatedAt = c.CreatedAt, UpdatedAt = c.UpdatedAt,
        Payments = c.Payments.Select(p => new ContractPaymentResponse
        {
            Id = p.Id, InstallmentNo = p.InstallmentNo, Amount = p.Amount,
            DueDate = p.DueDate, PaidAmount = p.PaidAmount, PaidDate = p.PaidDate,
            Status = p.Status, PaymentMode = p.PaymentMode
        }).ToList(),
    };
}
