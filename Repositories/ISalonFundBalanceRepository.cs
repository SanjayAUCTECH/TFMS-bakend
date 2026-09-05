using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ISalonFundBalanceRepository
{
    Task<SalonFundBalanceResponse> GetBalanceAsync(SalonFundBalanceRequest request);
}
