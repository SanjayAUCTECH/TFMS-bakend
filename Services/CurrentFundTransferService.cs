using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class CurrentFundTransferService : ICurrentFundTransferService
{
    private readonly ICurrentFundTransferRepository _repo;
    public CurrentFundTransferService(ICurrentFundTransferRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<CurrentFundTransferResponse>>> GetAllAsync(CurrentFundTransferListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<CurrentFundTransferResponse>>.Ok(
            data, "Retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<CurrentFundTransferResponse>> GetByIdAsync(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item is null
            ? ApiResponse<CurrentFundTransferResponse>.Fail("Record not found.")
            : ApiResponse<CurrentFundTransferResponse>.Ok(item);
    }

    public async Task<ApiResponse<CurrentFundTransferResponse>> CreateAsync(
        CreateCurrentFundTransferRequest request, string? addedBy)
    {
        int newId = await _repo.CreateAsync(request, addedBy);
        if (newId <= 0) return ApiResponse<CurrentFundTransferResponse>.Fail("Failed to create.");
        var created = await _repo.GetByIdAsync(newId);
        return ApiResponse<CurrentFundTransferResponse>.Ok(created!, "Created successfully.");
    }

    public async Task<ApiResponse<CurrentFundTransferResponse>> UpdateAsync(
        int id, UpdateCurrentFundTransferRequest request, string? updatedBy)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<CurrentFundTransferResponse>.Fail("Record not found.");
        await _repo.UpdateAsync(id, request, updatedBy);
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<CurrentFundTransferResponse>.Ok(updated!, "Updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, string? deletedBy)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Record not found.");
        await _repo.DeleteAsync(id, deletedBy);
        return ApiResponse<bool>.Ok(true, "Deleted successfully.");
    }
}
