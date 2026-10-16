using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IAlertTimeRepository
{
    Task<(IEnumerable<AlertTimeResponse> Data, int Total)> GetAllAsync(AlertTimeListRequest request);
    Task<AlertTimeResponse?> GetByIdAsync(int id);
    Task<AlertTimeResponse?> CreateAsync(CreateAlertTimeRequest request, int? userId);
    Task<AlertTimeResponse?> UpdateAsync(int id, UpdateAlertTimeRequest request, int? userId);
    Task<bool> DeleteAsync(int id, int? userId);
}
