using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IOwnerContractRepository
{
    Task<IEnumerable<OwnerContract>>     GetByCampAsync(int? campId, int? ownerId = null);
    Task<OwnerContract?>                 GetByIdAsync(int id);
    Task<int>                            CreateAsync(OwnerContract contract, string installmentsJson, string monthlyInstallmentsJson);
    Task<bool>                           UpdateAsync(int id, DTOs.UpdateOwnerContractRequest request, int? userId);
    Task<bool>                           DeleteAsync(int id, int? deletedBy = null);
    Task<IEnumerable<OwnerTransaction>>  GetTransactionsByContractIdAsync(int ownerContractId);
    Task<int>                            RenewAsync(RenewOwnerContractRequest request, int? userId);
    Task<IEnumerable<OwnerContractRenewalResponse>> GetRenewalsAsync(int? originalOwnerContractId);
}
