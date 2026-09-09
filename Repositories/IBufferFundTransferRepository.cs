using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IBufferFundTransferRepository
{
    Task<(IEnumerable<BufferFundTransferResponse> Data, int Total)> GetAllAsync(BufferFundTransferListRequest request);
    Task<BufferFundTransferResponse?>                               GetByIdAsync(int id);
    Task<int>                                                       CreateAsync(CreateBufferFundTransferRequest request, string? addedBy);
    Task                                                            UpdateAsync(int id, UpdateBufferFundTransferRequest request, string? updatedBy);
    Task                                                            DeleteAsync(int id, string? deletedBy);
}
