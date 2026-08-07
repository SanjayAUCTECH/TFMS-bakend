using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ITaskAlertRepository
{
    Task<(IEnumerable<TaskAlertMaster> Data, int TotalRecords)> GetAllAsync(TaskAlertListRequest request);
    Task<TaskAlertMaster?> GetByIdAsync(int id);
    Task<IEnumerable<TaskAlertMaster>> GetActiveAlertsAsync(int? assignPersonId = null);
    Task<int> CreateAsync(TaskAlertMaster task);
    Task<bool> UpdateAsync(TaskAlertMaster task);
    Task<bool> DeleteAsync(int id, int? deletedBy = null);
}
