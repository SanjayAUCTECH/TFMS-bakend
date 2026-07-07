using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public class RoomRepository : IRoomRepository
{
    private readonly IDbConnectionFactory _factory;
    public RoomRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<(IEnumerable<Room> Data, int TotalRecords)> GetAllAsync(RoomListRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetRooms", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize", request.ResolvedPageSize);
        cmd.Parameters.AddWithValue("@SearchText",    (object?)request.SearchText  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortBy",        (object?)request.SortBy      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SortDirection", request.ResolvedSortDir);
        cmd.Parameters.AddWithValue("@Status",        (object?)request.Status      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@CampId",        (object?)request.CampId      ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FloorId",       (object?)request.FloorId     ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RoomStatus",    (object?)request.RoomStatus  ?? DBNull.Value);
        var total = new SqlParameter("@TotalRecords", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(total);
        var list = new List<Room>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        await r.CloseAsync();
        return (list, (int)(total.Value == DBNull.Value ? 0 : total.Value));
    }

    public async Task<IEnumerable<Room>> GetVacantRoomsByCampAsync(int campId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("SELECT r.Id,r.RoomNo,r.CampId,c.Name CampName,r.FloorId,f.Name FloorName,r.Occupied,r.MonthlyPrice,r.Status,r.OtherDetails,r.CreatedAt,r.UpdatedAt FROM Rooms r JOIN Camps c ON c.Id=r.CampId JOIN Floors f ON f.Id=r.FloorId WHERE r.CampId=@CampId AND r.Occupied=0 ORDER BY r.RoomNo", conn);
        cmd.Parameters.AddWithValue("@CampId", campId);
        var list = new List<Room>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    public async Task<Room?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_GetRoomById", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? Map(r) : null;
    }

    public async Task<int> CreateAsync(Room room)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_CreateRoom", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@RoomNo",       room.RoomNo);
        cmd.Parameters.AddWithValue("@CampId",       room.CampId);
        cmd.Parameters.AddWithValue("@FloorId",      room.FloorId);
        cmd.Parameters.AddWithValue("@MonthlyPrice", room.MonthlyPrice);
        cmd.Parameters.AddWithValue("@Status",       room.Status);
        cmd.Parameters.AddWithValue("@OtherDetails", room.OtherDetails);
        var newId = new SqlParameter("@NewId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(newId);
        await cmd.ExecuteNonQueryAsync();
        return (int)newId.Value;
    }

    public async Task<bool> UpdateAsync(Room room)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_UpdateRoom", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id",           room.Id);
        cmd.Parameters.AddWithValue("@RoomNo",       room.RoomNo);
        cmd.Parameters.AddWithValue("@CampId",       room.CampId);
        cmd.Parameters.AddWithValue("@FloorId",      room.FloorId);
        cmd.Parameters.AddWithValue("@MonthlyPrice", room.MonthlyPrice);
        cmd.Parameters.AddWithValue("@Status",       room.Status);
        cmd.Parameters.AddWithValue("@OtherDetails", room.OtherDetails);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_DeleteRoom", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@Id", id);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<object> GetStatsAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(@"
            SELECT
                COUNT(*)                                                     AS totalRooms,
                SUM(CASE WHEN Status='Occupied'    THEN 1 ELSE 0 END)        AS occupied,
                SUM(CASE WHEN Status='Vacant'      THEN 1 ELSE 0 END)        AS vacant,
                SUM(CASE WHEN Status='Reserved'    THEN 1 ELSE 0 END)        AS reserved,
                SUM(CASE WHEN Status='Maintenance' THEN 1 ELSE 0 END)        AS maintenance
            FROM Rooms", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new { totalRooms=0, occupied=0, vacant=0, reserved=0, maintenance=0 };
        var total = r.IsDBNull(0) ? 0 : r.GetInt32(0);
        var occ   = r.IsDBNull(1) ? 0 : r.GetInt32(1);
        var vac   = r.IsDBNull(2) ? 0 : r.GetInt32(2);
        var occRate = total > 0 ? (int)Math.Round((double)occ / total * 100) : 0;
        return new { totalRooms = total, occupied = occ, vacant = vac, occupancyRate = occRate + "%" };
    }

    public async Task<BulkCreateRoomResponse> BulkCreateAsync(BulkCreateRoomRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("sp_BulkCreateRooms", conn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@CampId",       request.CampId);
        cmd.Parameters.AddWithValue("@FloorId",      request.FloorId);
        cmd.Parameters.AddWithValue("@RoomsJson",    System.Text.Json.JsonSerializer.Serialize(request.RoomNos));
        cmd.Parameters.AddWithValue("@Status",       request.Status);
        cmd.Parameters.AddWithValue("@Price",        request.MonthlyPrice);
        cmd.Parameters.AddWithValue("@OtherDetails", request.OtherDetails);
        await using var r = await cmd.ExecuteReaderAsync();
        int created = 0;
        if (await r.ReadAsync()) created = r.IsDBNull(0) ? 0 : r.GetInt32(0);
        return new BulkCreateRoomResponse
        {
            Created = created,
            Skipped = request.RoomNos.Count - created,
            Total   = request.RoomNos.Count,
            RoomNos = request.RoomNos,
        };
    }

    public async Task<bool> SetOccupiedAsync(int roomId, bool occupied)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new SqlCommand("UPDATE Rooms SET Occupied=@Occupied,Status=CASE WHEN @Occupied=1 THEN 'Occupied' ELSE 'Vacant' END,UpdatedAt=GETUTCDATE() WHERE Id=@Id", conn);
        cmd.Parameters.AddWithValue("@Occupied", occupied ? 1 : 0);
        cmd.Parameters.AddWithValue("@Id",       roomId);
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    private static Room Map(SqlDataReader r) => new()
    {
        Id           = r.GetInt32(r.GetOrdinal("Id")),
        RoomNo       = r.GetString(r.GetOrdinal("RoomNo")),
        CampId       = r.GetInt32(r.GetOrdinal("CampId")),
        CampName     = r.IsDBNull(r.GetOrdinal("CampName"))  ? "" : r.GetString(r.GetOrdinal("CampName")),
        FloorId      = r.GetInt32(r.GetOrdinal("FloorId")),
        FloorName    = r.IsDBNull(r.GetOrdinal("FloorName")) ? "" : r.GetString(r.GetOrdinal("FloorName")),
        Occupied     = r.GetBoolean(r.GetOrdinal("Occupied")),
        MonthlyPrice = r.GetDecimal(r.GetOrdinal("MonthlyPrice")),
        Status       = r.GetString(r.GetOrdinal("Status")),
        OtherDetails = r.IsDBNull(r.GetOrdinal("OtherDetails")) ? "" : r.GetString(r.GetOrdinal("OtherDetails")),
        CreatedAt    = r.GetDateTime(r.GetOrdinal("CreatedAt")),
        UpdatedAt    = r.GetDateTime(r.GetOrdinal("UpdatedAt")),
    };
}
