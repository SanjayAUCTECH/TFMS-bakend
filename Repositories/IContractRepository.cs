using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IContractRepository
{
    Task<(IEnumerable<Contract> Data, int TotalRecords)> GetAllAsync(ContractListRequest request);
    Task<Contract?>  GetByIdAsync(int id);
    Task<Contract?>  GetByContractIdAsync(string contractId);
    Task<string>     CreateAsync(Contract contract);   // returns ContractId
    Task<bool>       UpdateStatusAsync(string contractId, string status);
    Task<bool>       DeleteAsync(int id);
}
