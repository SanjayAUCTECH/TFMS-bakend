using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class BufferFundTransferService : IBufferFundTransferService
{
    private readonly IBufferFundTransferRepository _repo;
    public BufferFundTransferService(IBufferFundTransferRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<BufferFundTransferResponse>>> GetAllAsync(BufferFundTransferListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<BufferFundTransferResponse>>.Ok(
            data, "Retrieved successfully.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<BufferFundTransferResponse>> GetByIdAsync(int id)
    {
        var item = await _repo.GetByIdAsync(id);
        return item is null
            ? ApiResponse<BufferFundTransferResponse>.Fail("Record not found.")
            : ApiResponse<BufferFundTransferResponse>.Ok(item);
    }

    public async Task<ApiResponse<BufferFundTransferResponse>> CreateAsync(
        CreateBufferFundTransferRequest request, string? addedBy)
    {
        int newId = await _repo.CreateAsync(request, addedBy);
        if (newId <= 0) return ApiResponse<BufferFundTransferResponse>.Fail("Failed to create.");
        var created = await _repo.GetByIdAsync(newId);
        return ApiResponse<BufferFundTransferResponse>.Ok(created!, "Created successfully.");
    }

    public async Task<ApiResponse<BufferFundTransferResponse>> UpdateAsync(
        int id, UpdateBufferFundTransferRequest request, string? updatedBy)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<BufferFundTransferResponse>.Fail("Record not found.");
        await _repo.UpdateAsync(id, request, updatedBy);
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<BufferFundTransferResponse>.Ok(updated!, "Updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, string? deletedBy)
    {
        if (await _repo.GetByIdAsync(id) is null)
            return ApiResponse<bool>.Fail("Record not found.");
        await _repo.DeleteAsync(id, deletedBy);
        return ApiResponse<bool>.Ok(true, "Deleted successfully.");
    }
}
