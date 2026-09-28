-- =============================================
-- Stored Procedure: sp_GetMonthwiseOccupiedRooms
-- Description: Get month-wise occupied rooms from ContractRoomInstallments
--              Only includes rooms from Active or Completed contracts
--              Supports pagination
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetMonthwiseOccupiedRooms
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
        AND (@Month IS NULL OR cri.Month = @Month)
    ORDER BY cri.CampName, cri.RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
END;
GO

-- =============================================
-- Test Script
-- =============================================

/*
-- Test 1: Get occupied rooms for August 2026 (Page 1, 10 records)
DECLARE @Total INT;
EXEC sp_GetMonthwiseOccupiedRooms 
    @Month = 'Aug26',
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 2: Get all occupied rooms (No month filter, Page 1, 20 records)
DECLARE @Total INT;
EXEC sp_GetMonthwiseOccupiedRooms 
    @Month = NULL,
    @PageNumber = 1,
    @PageSize = 20,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 3: Get occupied rooms for July 2026 (Page 2, 50 records)
DECLARE @Total INT;
EXEC sp_GetMonthwiseOccupiedRooms 
    @Month = 'Jul26',
    @PageNumber = 2,
    @PageSize = 50,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;
*/
