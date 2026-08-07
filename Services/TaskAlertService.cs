using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class TaskAlertService : ITaskAlertService
{
    private static readonly string[] ValidStatuses = { "Running", "Complete", "Partial", "Cancel" };
    private readonly ITaskAlertRepository _repo;
    public TaskAlertService(ITaskAlertRepository repo) => _repo = repo;

    public async Task<ApiResponse<IEnumerable<TaskAlertResponse>>> GetAllAsync(TaskAlertListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        return ApiResponse<IEnumerable<TaskAlertResponse>>.Ok(
            data.Select(ToResponse), "Task alerts retrieved.",
            PaginationHelper.Build(total, request.ResolvedPageNumber, request.ResolvedPageSize));
    }

    public async Task<ApiResponse<TaskAlertResponse>> GetByIdAsync(int id)
    {
        var t = await _repo.GetByIdAsync(id);
        return t == null
            ? ApiResponse<TaskAlertResponse>.Fail("Task alert not found.")
            : ApiResponse<TaskAlertResponse>.Ok(ToResponse(t));
    }

    public async Task<ApiResponse<IEnumerable<TaskAlertActiveResponse>>> GetActiveAlertsAsync(int? assignPersonId = null)
    {
        var data = await _repo.GetActiveAlertsAsync(assignPersonId);
        var response = data.Select(t => new TaskAlertActiveResponse
        {
            Id               = t.Id,
            TaskId           = t.TaskId,
            TaskDate         = t.TaskDate,
            TaskTitle        = t.TaskTitle,
            TaskDescription  = t.TaskDescription,
            TaskStatus       = t.TaskStatus,
            PartialRemark    = t.PartialRemark,
            AssignPersonId   = t.AssignPersonId,
            AssignPersonName = t.AssignPersonName,
            CreatedAt        = t.CreatedAt,
            UpdatedAt        = t.UpdatedAt,
            DaysOverdue      = (int)(DateTime.Today - t.TaskDate.Date).TotalDays,
        });
        return ApiResponse<IEnumerable<TaskAlertActiveResponse>>.Ok(response, "Active task alerts retrieved.");
    }

    public async Task<ApiResponse<TaskAlertResponse>> CreateAsync(CreateTaskAlertRequest request, int? userId = null)
    {
        if (!ValidStatuses.Contains(request.TaskStatus))
            return ApiResponse<TaskAlertResponse>.Fail($"Invalid status. Must be: {string.Join(", ", ValidStatuses)}");

        var id = await _repo.CreateAsync(new TaskAlertMaster
        {
            TaskDate         = request.TaskDate,
            TaskTitle        = request.TaskTitle.Trim(),
            TaskDescription  = request.TaskDescription,
            TaskStatus       = request.TaskStatus,
            PartialRemark    = request.PartialRemark,
            AssignPersonId   = request.AssignPersonId,
            AssignPersonName = request.AssignPersonName,
            AddedBy          = userId,
        });
        var created = await _repo.GetByIdAsync(id);
        return ApiResponse<TaskAlertResponse>.Ok(ToResponse(created!), "Task alert created successfully.");
    }

    public async Task<ApiResponse<TaskAlertResponse>> UpdateAsync(int id, UpdateTaskAlertRequest request, int? userId = null)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return ApiResponse<TaskAlertResponse>.Fail("Task alert not found.");

        if (!ValidStatuses.Contains(request.TaskStatus))
            return ApiResponse<TaskAlertResponse>.Fail($"Invalid status. Must be: {string.Join(", ", ValidStatuses)}");

        await _repo.UpdateAsync(new TaskAlertMaster
        {
            Id               = id,
            TaskDate         = request.TaskDate,
            TaskTitle        = request.TaskTitle.Trim(),
            TaskDescription  = request.TaskDescription,
            TaskStatus       = request.TaskStatus,
            PartialRemark    = request.PartialRemark,
            AssignPersonId   = request.AssignPersonId,
            AssignPersonName = request.AssignPersonName,
            UpdatedBy        = userId,
        });
        var updated = await _repo.GetByIdAsync(id);
        return ApiResponse<TaskAlertResponse>.Ok(ToResponse(updated!), "Task alert updated successfully.");
    }

    public async Task<ApiResponse<bool>> DeleteAsync(int id, int? userId = null)
    {
        if (await _repo.GetByIdAsync(id) == null)
            return ApiResponse<bool>.Fail("Task alert not found.");
        await _repo.DeleteAsync(id, userId);
        return ApiResponse<bool>.Ok(true, "Task alert deleted.");
    }

    private static TaskAlertResponse ToResponse(TaskAlertMaster t) => new()
    {
        Id               = t.Id,
        TaskId           = t.TaskId,
        TaskDate         = t.TaskDate,
        TaskTitle        = t.TaskTitle,
        TaskDescription  = t.TaskDescription,
        TaskStatus       = t.TaskStatus,
        PartialRemark    = t.PartialRemark,
        AssignPersonId   = t.AssignPersonId,
        AssignPersonName = t.AssignPersonName,
        CreatedAt        = t.CreatedAt,
        UpdatedAt        = t.UpdatedAt,
    };
}
