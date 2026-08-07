using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class TaskAlertRepository : ITaskAlertRepository
{
    private readonly IDbConnectionFactory _factory;
    public TaskAlertRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<TaskAlertMaster> Data, int TotalRecords)> GetAllAsync(TaskAlertListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTaskAlerts", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber",     request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",       request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",     (object?)request.SearchText     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@TaskStatus",     (object?)request.TaskStatus     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AssignPersonId", (object?)request.AssignPersonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateFrom",       (object?)request.DateFrom       ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",         (object?)request.DateTo         ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<TaskAlertMaster>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<TaskAlertMaster?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetTaskAlertById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<IEnumerable<TaskAlertMaster>> GetActiveAlertsAsync(int? assignPersonId = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetActiveTaskAlerts", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@AssignPersonId", (object?)assignPersonId ?? DBNull.Value);
        var list = new List<TaskAlertMaster>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var t = Map(r);
            list.Add(t);
        }
        return list;
    }

    public async Task<int> CreateAsync(TaskAlertMaster task)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateTaskAlert", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@TaskDate",         task.TaskDate);
        cmd.Parameters.AddWithValue("@TaskTitle",        task.TaskTitle);
        cmd.Parameters.AddWithValue("@TaskDescription",  task.TaskDescription);
        cmd.Parameters.AddWithValue("@TaskStatus",       task.TaskStatus);
        cmd.Parameters.AddWithValue("@PartialRemark",    task.PartialRemark);
        cmd.Parameters.AddWithValue("@AssignPersonId",   (object?)task.AssignPersonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AssignPersonName", task.AssignPersonName);
        cmd.Parameters.AddWithValue("@AddedBy",          (object?)task.AddedBy ?? DBNull.Value);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(TaskAlertMaster task)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateTaskAlert", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",               task.Id);
        cmd.Parameters.AddWithValue("@TaskDate",         task.TaskDate);
        cmd.Parameters.AddWithValue("@TaskTitle",        task.TaskTitle);
        cmd.Parameters.AddWithValue("@TaskDescription",  task.TaskDescription);
        cmd.Parameters.AddWithValue("@TaskStatus",       task.TaskStatus);
        cmd.Parameters.AddWithValue("@PartialRemark",    task.PartialRemark);
        cmd.Parameters.AddWithValue("@AssignPersonId",   (object?)task.AssignPersonId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AssignPersonName", task.AssignPersonName);
        cmd.Parameters.AddWithValue("@UpdatedBy",        (object?)task.UpdatedBy ?? DBNull.Value);
        return await cmd.ExecuteNonQueryAsync() >= 0;
    }

    public async Task<bool> DeleteAsync(int id, int? deletedBy = null)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteTaskAlert", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",        id);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    private static TaskAlertMaster Map(SqlDataReader r) => new()
    {
        Id               = r.GetInt32(r.GetOrdinal("Id")),
        TaskId           = r.IsDBNull(r.GetOrdinal("TaskId"))           ? "" : r.GetString(r.GetOrdinal("TaskId")),
        TaskDate         = r.GetDateTime(r.GetOrdinal("TaskDate")),
        TaskTitle        = r.IsDBNull(r.GetOrdinal("TaskTitle"))        ? "" : r.GetString(r.GetOrdinal("TaskTitle")),
        TaskDescription  = r.IsDBNull(r.GetOrdinal("TaskDescription"))  ? "" : r.GetString(r.GetOrdinal("TaskDescription")),
        TaskStatus       = r.IsDBNull(r.GetOrdinal("TaskStatus"))       ? "" : r.GetString(r.GetOrdinal("TaskStatus")),
        PartialRemark    = r.IsDBNull(r.GetOrdinal("PartialRemark"))    ? "" : r.GetString(r.GetOrdinal("PartialRemark")),
        AssignPersonId   = r.IsDBNull(r.GetOrdinal("AssignPersonId"))   ? null : r.GetInt32(r.GetOrdinal("AssignPersonId")),
        AssignPersonName = r.IsDBNull(r.GetOrdinal("AssignPersonName")) ? "" : r.GetString(r.GetOrdinal("AssignPersonName")),
        CreatedAt        = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt        = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
