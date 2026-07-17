using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IContractCancellationRepository
{
    Task<int> CancelAsync(CancelContractRequest request);
    Task<IEnumerable<ContractCancellationResponse>> GetAllAsync(string? contractId);
}
