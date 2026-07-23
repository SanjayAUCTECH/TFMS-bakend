using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IOwnerContractRepository
{
    Task<IEnumerable<OwnerContract>>     GetByCampAsync(int? campId);
    Task<OwnerContract?>                 GetByIdAsync(int id);
    Task<int>                            CreateAsync(OwnerContract contract, string installmentsJson, string monthlyInstallmentsJson);
    Task<bool>                           DeleteAsync(int id);
    Task<IEnumerable<OwnerTransaction>>  GetTransactionsByContractIdAsync(int ownerContractId);
}
