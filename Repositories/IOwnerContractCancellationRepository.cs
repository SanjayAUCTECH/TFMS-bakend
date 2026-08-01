using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IOwnerContractCancellationRepository
{
    Task<int>  CancelAsync(CancelOwnerContractRequest request, int? userId);
    Task<IEnumerable<OwnerContractCancellationResponse>> GetAllAsync(int? ownerContractId);
}
