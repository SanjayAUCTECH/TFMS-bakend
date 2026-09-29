-- =============================================
-- Script: Update Monthwise Procedures with Camp Filter
-- Description: Updates sp_GetMonthwiseOccupiedRooms and sp_GetMonthwiseVacantRooms
--              to add @CampId parameter for filtering by camp
-- Date: 2026-09-28
-- =============================================

USE [TFMS_TestSoftwareDB];
GO

PRINT '======================================';
PRINT 'Updating sp_GetMonthwiseOccupiedRooms';
PRINT '======================================';

-- =============================================
-- Stored Procedure: sp_GetMonthwiseOccupiedRooms
-- Description: Get month-wise occupied rooms from ContractRoomInstallments
--              Only includes rooms from Active or Completed contracts
--              Supports pagination and camp filter
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetMonthwiseOccupiedRooms
    @CampId INT = NULL,
    @Month NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Calculate offset for pagination
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get total count of occupied rooms
    SELECT @TotalRecords = COUNT(DISTINCT cri.Id)
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON cri.ContractId = c.ContractId
    WHERE (c.Status = 'Active' OR c.Status = 'Completed' OR c.Status = 'Complete')
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@Month IS NULL OR cri.Month = @Month);
    
    -- Get paginated occupied rooms data
    SELECT DISTINCT
        cri.Id,
        cri.ContractId,
        cri.CampId,
        cri.CampName,
        cri.RoomId,
        cri.RoomNo,
        cri.Month,
        cri.DueDate,
        cri.InstallmentNo,
        cri.InstallAmount,
        cri.Status as InstallmentStatus,
        cri.PaidAmount,
        cri.Balance,
        c.Status as ContractStatus,
        c.TenantId,
        c.StartDate,
        c.EndDate,
        c.ContractType
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON cri.ContractId = c.ContractId
    WHERE (c.Status = 'Active' OR c.Status = 'Completed' OR c.Status = 'Complete')
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@Month IS NULL OR cri.Month = @Month)
    ORDER BY cri.CampName, cri.RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
END;
GO

PRINT 'sp_GetMonthwiseOccupiedRooms updated successfully!';
PRINT '';

PRINT '=====================================';
PRINT 'Updating sp_GetMonthwiseVacantRooms';
PRINT '=====================================';

-- =============================================
-- Stored Procedure: sp_GetMonthwiseVacantRooms
-- Description: Get month-wise vacant/empty rooms
--              Returns rooms that are NOT in ContractRoomInstallments
--              for the specified month
--              Supports pagination and camp filter
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetMonthwiseVacantRooms
    @CampId INT = NULL,
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
        AND r.IsDeleted = 0
        AND (@CampId IS NULL OR r.CampId = @CampId);
    
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
        AND (@CampId IS NULL OR r.CampId = @CampId)
    ORDER BY c.Name, r.RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
END;
GO

PRINT 'sp_GetMonthwiseVacantRooms updated successfully!';
PRINT '';
PRINT '======================================';
PRINT 'All procedures updated successfully!';
PRINT '======================================';
PRINT '';
PRINT 'Testing procedures...';
PRINT '';

-- =============================================
-- Test Script
-- =============================================

-- Test 1: Occupied rooms with camp filter
PRINT '-- Test 1: Occupied rooms for CampId = 7';
DECLARE @Total1 INT;
EXEC sp_GetMonthwiseOccupiedRooms 
    @CampId = 7,
    @Month = NULL,
    @PageNumber = 1,
    @PageSize = 5,
    @TotalRecords = @Total1 OUTPUT;
PRINT 'Total Records: ' + CAST(@Total1 AS NVARCHAR);
PRINT '';

-- Test 2: Vacant rooms with camp filter
PRINT '-- Test 2: Vacant rooms for CampId = 1';
DECLARE @Total2 INT;
EXEC sp_GetMonthwiseVacantRooms 
    @CampId = 1,
    @Month = NULL,
    @PageNumber = 1,
    @PageSize = 5,
    @TotalRecords = @Total2 OUTPUT;
PRINT 'Total Records: ' + CAST(@Total2 AS NVARCHAR);
PRINT '';

-- Test 3: Occupied rooms with both filters
PRINT '-- Test 3: Occupied rooms for CampId = 7 and Month = Jul26';
DECLARE @Total3 INT;
EXEC sp_GetMonthwiseOccupiedRooms 
    @CampId = 7,
    @Month = 'Jul26',
    @PageNumber = 1,
    @PageSize = 5,
    @TotalRecords = @Total3 OUTPUT;
PRINT 'Total Records: ' + CAST(@Total3 AS NVARCHAR);
PRINT '';

PRINT '======================================';
PRINT 'Update script completed successfully!';
PRINT '======================================';
