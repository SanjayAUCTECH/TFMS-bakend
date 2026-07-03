using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class ExpenseRepository : IExpenseRepository
{
    private readonly IDbConnectionFactory _factory;
    public ExpenseRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Expense> Data, int TotalRecords)> GetAllAsync(ExpenseListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetExpenses", conn) { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.AddWithValue("@PageNumber",    request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",      request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@DateFrom",      (object?)request.DateFrom      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateTo",        (object?)request.DateTo        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Head",          (object?)request.Head          ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Nature",        (object?)request.Nature        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId        ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientRole", (object?)request.RecipientRole ?? DBNull.Value);

        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);

        var list = new List<Expense>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapExpense(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<Expense?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetExpenseById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapExpense(r) : null;
    }

    public async Task<int> CreateAsync(Expense expense)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateExpense", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Date",          expense.Date);
        cmd.Parameters.AddWithValue("@Mode",          expense.Mode);
        cmd.Parameters.AddWithValue("@Head",          expense.Head);
        cmd.Parameters.AddWithValue("@FundPool",      expense.FundPool);
        cmd.Parameters.AddWithValue("@Amount",        expense.Amount);
        cmd.Parameters.AddWithValue("@Nature",        expense.Nature);
        cmd.Parameters.AddWithValue("@CampId",        (object?)expense.CampId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientRole", expense.RecipientRole);
        cmd.Parameters.AddWithValue("@RecipientName", expense.RecipientName);
        cmd.Parameters.AddWithValue("@Purpose",       expense.Purpose);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Expense expense)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateExpense", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",            expense.Id);
        cmd.Parameters.AddWithValue("@Date",          expense.Date);
        cmd.Parameters.AddWithValue("@Mode",          expense.Mode);
        cmd.Parameters.AddWithValue("@Head",          expense.Head);
        cmd.Parameters.AddWithValue("@FundPool",      expense.FundPool);
        cmd.Parameters.AddWithValue("@Amount",        expense.Amount);
        cmd.Parameters.AddWithValue("@Nature",        expense.Nature);
        cmd.Parameters.AddWithValue("@CampId",        (object?)expense.CampId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecipientRole", expense.RecipientRole);
        cmd.Parameters.AddWithValue("@RecipientName", expense.RecipientName);
        cmd.Parameters.AddWithValue("@Purpose",       expense.Purpose);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteExpense", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT COUNT(1) FROM Expenses WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    private static Expense MapExpense(SqlDataReader r) => new()
    {
        Id            = r.GetInt32(r.GetOrdinal("Id")),
        ExpenseId     = r.GetString(r.GetOrdinal("ExpenseId")),
        Date          = r.GetDateTime(r.GetOrdinal("Date")),
        Mode          = r.IsDBNull(r.GetOrdinal("Mode"))          ? "" : r.GetString(r.GetOrdinal("Mode")),
        Head          = r.IsDBNull(r.GetOrdinal("Head"))          ? "" : r.GetString(r.GetOrdinal("Head")),
        FundPool      = r.IsDBNull(r.GetOrdinal("FundPool"))      ? "" : r.GetString(r.GetOrdinal("FundPool")),
        FundPoolName  = r.IsDBNull(r.GetOrdinal("FundPoolName"))  ? "" : r.GetString(r.GetOrdinal("FundPoolName")),
        Amount        = r.GetDecimal(r.GetOrdinal("Amount")),
        Nature        = r.IsDBNull(r.GetOrdinal("Nature"))        ? "HO" : r.GetString(r.GetOrdinal("Nature")),
        CampId        = r.IsDBNull(r.GetOrdinal("CampId"))        ? null : r.GetInt32(r.GetOrdinal("CampId")),
        CampName      = r.IsDBNull(r.GetOrdinal("CampName"))      ? "" : r.GetString(r.GetOrdinal("CampName")),
        RecipientRole = r.IsDBNull(r.GetOrdinal("RecipientRole")) ? "" : r.GetString(r.GetOrdinal("RecipientRole")),
        RecipientName = r.IsDBNull(r.GetOrdinal("RecipientName")) ? "" : r.GetString(r.GetOrdinal("RecipientName")),
        Purpose       = r.IsDBNull(r.GetOrdinal("Purpose"))       ? "" : r.GetString(r.GetOrdinal("Purpose")),
        CreatedAt     = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt     = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
