using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IContractTermRepository
{
    Task<IEnumerable<ContractTermResponse>> GetByContractIdAsync(string contractId);
    Task<IEnumerable<ContractTermResponse>> SaveAsync(string contractId, List<ContractTermItem> terms);
}
