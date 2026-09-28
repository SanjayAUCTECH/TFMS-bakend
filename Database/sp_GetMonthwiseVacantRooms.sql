-- =============================================
-- Stored Procedure: sp_GetMonthwiseVacantRooms
-- Description: Get month-wise vacant/empty rooms
--              Returns rooms that are NOT in ContractRoomInstallments
--              for the specified month
--              Supports pagination
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetMonthwiseVacantRooms
    @Month NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Calculate offset for pagination
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get total count of vacant rooms
    SELECT @TotalRecords = COUNT(DISTINCT r.Id)
    FROM Rooms r
    LEFT JOIN (
        SELECT DISTINCT cri.RoomId
        FROM ContractRoomInstallments cri
        INNER JOIN Contracts c ON cri.ContractId = c.ContractId
        WHERE (c.Status = 'Active' OR c.Status = 'Completed' OR c.Status = 'Complete')
            AND (@Month IS NULL OR cri.Month = @Month)
    ) occupied ON r.Id = occupied.RoomId
    WHERE occupied.RoomId IS NULL 
        AND r.IsDeleted = 0;
    
    -- Get paginated vacant rooms data
    SELECT 
        r.Id as RoomId,
        r.RoomNo,
        r.CampId,
        c.Name as CampName,
        r.FloorId,
        f.Name as FloorName,
        r.Occupied,
        r.MonthlyPrice,
        r.Status as RoomStatus,
        r.OtherDetails
    FROM Rooms r
    LEFT JOIN Camps c ON r.CampId = c.Id
    LEFT JOIN Floors f ON r.FloorId = f.Id
    LEFT JOIN (
        SELECT DISTINCT cri.RoomId
        FROM ContractRoomInstallments cri
        INNER JOIN Contracts ct ON cri.ContractId = ct.ContractId
        WHERE (ct.Status = 'Active' OR ct.Status = 'Completed' OR ct.Status = 'Complete')
            AND (@Month IS NULL OR cri.Month = @Month)
    ) occupied ON r.Id = occupied.RoomId
    WHERE occupied.RoomId IS NULL 
        AND r.IsDeleted = 0
    ORDER BY c.Name, r.RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
END;
GO

-- =============================================
-- Test Script
-- =============================================

/*
-- Test 1: Get vacant rooms for July 2026 (Page 1, 10 records)
DECLARE @Total INT;
EXEC sp_GetMonthwiseVacantRooms 
    @Month = 'Jul26',
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 2: Get all vacant rooms (No month filter, Page 1, 20 records)
DECLARE @Total INT;
EXEC sp_GetMonthwiseVacantRooms 
    @Month = NULL,
    @PageNumber = 1,
    @PageSize = 20,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 3: Get vacant rooms for August 2026 (Page 2, 50 records)
DECLARE @Total INT;
EXEC sp_GetMonthwiseVacantRooms 
    @Month = 'Aug26',
    @PageNumber = 2,
    @PageSize = 50,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;
*/
