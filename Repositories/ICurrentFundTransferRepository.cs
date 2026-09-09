using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ICurrentFundTransferRepository
{
    Task<(IEnumerable<CurrentFundTransferResponse> Data, int Total)> GetAllAsync(CurrentFundTransferListRequest request);
    Task<CurrentFundTransferResponse?>                               GetByIdAsync(int id);
    Task<int>                                                        CreateAsync(CreateCurrentFundTransferRequest request, string? addedBy);
    Task                                                             UpdateAsync(int id, UpdateCurrentFundTransferRequest request, string? updatedBy);
    Task                                                             DeleteAsync(int id, string? deletedBy);
}
