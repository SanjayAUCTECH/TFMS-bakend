using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class SalonFundBalanceService : ISalonFundBalanceService
{
    private readonly ISalonFundBalanceRepository _repo;
    public SalonFundBalanceService(ISalonFundBalanceRepository repo) => _repo = repo;

    public async Task<ApiResponse<SalonFundBalanceResponse>> GetBalanceAsync(SalonFundBalanceRequest request)
    {
        var data = await _repo.GetBalanceAsync(request);
        return ApiResponse<SalonFundBalanceResponse>.Ok(data, "Salon fund balance retrieved successfully.");
    }
}
