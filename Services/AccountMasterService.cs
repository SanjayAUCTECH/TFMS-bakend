using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class AccountMasterService : IAccountMasterService
{
    private readonly IAccountMasterRepository _repo;
    private readonly IFundPoolRepository _fundRepo;

    public AccountMasterService(IAccountMasterRepository repo, IFundPoolRepository fundRepo)
    {
        _repo = repo;
        _fundRepo = fundRepo;
    }

    public async Task<ApiResponse<IEnumerable<AccountMasterDetailResponse>>> GetAllAsync(AccountMasterListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var responseList = new List<AccountMasterDetailResponse>();
        foreach (var m in data)
        {
            var heads = await _repo.GetHeadsByAccountIdAsync(m.AccountId);
            responseList.Add(ToDetailResponse(m, heads));
        }
        return ApiResponse<IEnumerable<AccountMasterDetailResponse>>.Ok(
            responseList, "Account masters retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<AccountMasterDetailResponse>> GetByIdAsync(int id)
    {
        var master = await _repo.GetByIdAsync(id);
        if (master == null) return ApiResponse<AccountMasterDetailResponse>.Fail("Not found.");

        var heads = await _repo.GetHeadsByAccountIdAsync(master.AccountId);
        var detail = ToDetailResponse(master, heads);
        return ApiResponse<AccountMasterDetailResponse>.Ok(detail);
    }

    public async Task<ApiResponse<AccountMasterDetailResponse>> CreateAsync(CreateAccountMasterRequest request, int? userId = null)
    {
        if (request.Heads == null || request.Heads.Count == 0)
            return ApiResponse<AccountMasterDetailResponse>.Fail("At least one head item is required.");

        foreach (var h in request.Heads)
        {
            if (string.IsNullOrWhiteSpace(h.PaymentType) || (h.PaymentType != "Income" && h.PaymentType != "Expense"))
                return ApiResponse<AccountMasterDetailResponse>.Fail($"Invalid PaymentType '{h.PaymentType}'. Must be 'Income' or 'Expense'.");
            if (h.Amount <= 0)
                return ApiResponse<AccountMasterDetailResponse>.Fail("Each head amount must be greater than 0.");
        }

        // Resolve FundPool
        string fundPoolCode = "", fundPoolName = request.FundPoolName ?? "";
        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp != null) { fundPoolCode = fp.Code; fundPoolName = fp.Name; }
        }

        var master = new AccountMaster
        {
            TransDate     = request.TransDate,
            Mode          = request.Mode,
            FundPool      = fundPoolCode,
            FundPoolName  = fundPoolName,
            Nature        = request.Nature,
            RecipientRole = request.RecipientRole,
            RecipientId   = request.RecipientId,
            RecipientName = request.RecipientName,
            Purpose       = request.Purpose,
            CampId        = request.CampId,
            CampName      = request.CampName,
        };

        int newId;
        try
        {
            newId = await _repo.CreateAsync(master, request.Heads, userId,
                string.IsNullOrWhiteSpace(request.VoucherNo) ? null : request.VoucherNo);
        }
        catch (InvalidOperationException ex) when (ex.Message == "VOUCHER_EXISTS")
        {
            return ApiResponse<AccountMasterDetailResponse>.Fail($"VoucherNo '{request.VoucherNo}' already exists.");
        }
        var created = await _repo.GetByIdAsync(newId);
        var heads = await _repo.GetHeadsByAccountIdAsync(created!.AccountId);

        return ApiResponse<AccountMasterDetailResponse>.Ok(
            ToDetailResponse(created, heads), "Account master created successfully.");
    }

    public async Task<ApiResponse<AccountMasterDetailResponse>> UpdateAsync(int id, UpdateAccountMasterRequest request, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<AccountMasterDetailResponse>.Fail("Not found.");

        if (request.Heads == null || request.Heads.Count == 0)
            return ApiResponse<AccountMasterDetailResponse>.Fail("At least one head item is required.");

        // Resolve FundPool
        string fundPoolCode = "", fundPoolName = request.FundPoolName ?? "";
        if (request.FundPoolId.HasValue)
        {
            var fp = await _fundRepo.GetByIdAsync(request.FundPoolId.Value);
            if (fp != null) { fundPoolCode = fp.Code; fundPoolName = fp.Name; }
        }

        var master = new AccountMaster
        {
            TransDate     = request.TransDate,
            Mode          = request.Mode,
            FundPool      = fundPoolCode,
            FundPoolName  = fundPoolName,
            Nature        = request.Nature,
            RecipientRole = request.RecipientRole,
            RecipientId   = request.RecipientId,
            RecipientName = request.RecipientName,
            Purpose       = request.Purpose,
            CampId        = request.CampId,
            CampName      = request.CampName,
        };

        await _repo.UpdateAsync(id, master, request.Heads, userId);
        var updated = await _repo.GetByIdAsync(id);
        var heads = await _repo.GetHeadsByAccountIdAsync(updated!.AccountId);
        return ApiResponse<AccountMasterDetailResponse>.Ok(
            ToDetailResponse(updated, heads), "Account master updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<bool>.Fail("Not found.");

        var ok = await _repo.DeleteAsync(id, userId);
        return ok ? ApiResponse<bool>.Ok(true, "Deleted.") : ApiResponse<bool>.Fail("Delete failed.");
    }

    private static AccountMasterResponse ToResponse(AccountMaster m) => new()
    {
        Id            = m.Id,
        AccountId     = m.AccountId,
        VoucherNo     = m.VoucherNo,
        TransDate     = m.TransDate,
        PaymentType   = m.PaymentType,
        Mode          = m.Mode,
        FundPool      = m.FundPool,
        FundPoolName  = m.FundPoolName,
        Amount        = m.Amount,
        Nature        = m.Nature,
        RecipientRole = m.RecipientRole,
        RecipientName = m.RecipientName,
        Purpose       = m.Purpose,
        RecipientId   = m.RecipientId,
        CreatedAt     = m.CreatedAt,
        UpdatedAt     = m.UpdatedAt,
    };

    private static AccountMasterDetailResponse ToDetailResponse(
        AccountMaster m,
        List<(int Id, string PaymentType, string Head, decimal Amount, string Purpose, string RefId, int? CampId, string CampName)> heads)
    {
        // Get CampId/CampName from first head that has it
        var firstWithCamp = heads.FirstOrDefault(h => h.CampId.HasValue && h.CampId > 0);

        return new()
        {
            Id            = m.Id,
            AccountId     = m.AccountId,
            VoucherNo     = m.VoucherNo,
            TransDate     = m.TransDate,
            PaymentType   = m.PaymentType,
            Mode          = m.Mode,
            FundPool      = m.FundPool,
            FundPoolName  = m.FundPoolName,
            Amount        = m.Amount,
            Nature        = m.Nature,
            CampId        = firstWithCamp.CampId,
            CampName      = firstWithCamp.CampName ?? "",
            RecipientRole = m.RecipientRole,
            RecipientName = m.RecipientName,
            Purpose       = m.Purpose,
            RecipientId   = m.RecipientId,
            CreatedAt     = m.CreatedAt,
            UpdatedAt     = m.UpdatedAt,
            Heads         = heads.Select(h => new AccountMasterHeadResponse
            {
                Id          = h.Id,
                PaymentType = h.PaymentType,
                Head        = h.Head,
                Amount      = h.Amount,
                Purpose     = h.Purpose,
                RefId       = h.RefId,
            }).ToList(),
        };
    }
}
