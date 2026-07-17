using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IContractRenewalRepository
{
    Task<string> RenewAsync(RenewContractRequest request);
    Task<IEnumerable<ContractRenewalResponse>> GetRenewalsAsync(string? contractId);
}
