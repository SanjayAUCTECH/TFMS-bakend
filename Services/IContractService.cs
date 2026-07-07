using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IContractService
{
    Task<ApiResponse<IEnumerable<ContractResponse>>> GetAllAsync(ContractListRequest request);
    Task<ApiResponse<ContractResponse>>              GetByIdAsync(int id);
    Task<ApiResponse<ContractResponse>>              GetByContractIdAsync(string contractId);
    Task<ApiResponse<ContractResponse>>              CreateAsync(CreateContractRequest request);
    Task<ApiResponse<bool>>                          UpdateStatusAsync(string contractId, UpdateContractStatusRequest request);
    Task<ApiResponse<bool>>                          DeleteAsync(int id);
    Task<ApiResponse<bool>>                          UpdateScheduleAsync(UpdateContractScheduleRequest request);
    Task<ApiResponse<ContractResponse>>              UpdateContractAsync(UpdateContractRequest request);
}
