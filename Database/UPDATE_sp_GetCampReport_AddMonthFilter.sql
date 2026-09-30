-- =============================================
-- Update sp_GetCampReport to add Month filter
-- Filter applied on ContractRoomInstallments.Month column
-- =============================================

USE [TFMS_TestSoftwareDB];
GO

-- Drop existing procedure
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetCampReport')
    DROP PROCEDURE sp_GetCampReport;
GO

-- Create updated procedure with Month parameter
CREATE PROCEDURE sp_GetCampReport
    @PageNumber INT = 1,
    @PageSize INT = 2147483647,
    @SearchText NVARCHAR(MAX) = NULL,
    @Status NVARCHAR(MAX) = NULL,
    @Month VARCHAR(7) = NULL,                    -- ✅ NEW PARAMETER (format: yyyy-MM)
    @TotalRecords INT OUTPUT
AS 
BEGIN
    SET NOCOUNT ON;
    
    -- Count total records
    SELECT @TotalRecords = COUNT(*) 
    FROM Camps ca 
    WHERE ca.IsDeleted = 0
      AND (@Status IS NULL OR ca.Status = @Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%' + @SearchText + '%');
    
    -- Get camp report with month filter
    SELECT 
        ca.Id AS CampId,
        ca.Code AS CampCode,
        ca.Name AS CampName,
        ca.Status,
        
        -- Room statistics
        COUNT(DISTINCT r.Id) AS TotalRooms,
        COUNT(DISTINCT CASE WHEN r.Status = 'Occupied' THEN r.Id END) AS OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r.Status = 'Vacant' THEN r.Id END) AS VacantRooms,
        COUNT(DISTINCT CASE WHEN c.Status = 'Active' THEN c.Id END) AS ActiveContracts,
        
        -- Total Monthly Rent
        ISNULL(SUM(CASE WHEN r.Status = 'Occupied' THEN r.MonthlyPrice ELSE 0 END), 0) AS TotalMonthlyRent,
        
        -- TotalCollected: ContractRoomInstallments where Status IN (Paid, PaidPartial)
        -- ✅ UPDATED: Added Month filter
        ISNULL((
            SELECT SUM(cri.PaidAmount) 
            FROM ContractRoomInstallments cri
            INNER JOIN ContractRooms cr ON cr.ContractId = cri.ContractId 
                AND cr.RoomId = cri.RoomId 
                AND ISNULL(cr.IsDeleted, 0) = 0
            WHERE cr.CampId = ca.Id 
              AND ISNULL(cri.IsDeleted, 0) = 0
              AND cri.Status IN ('Paid', 'PaidPartial')
              AND (@Month IS NULL OR cri.Month = @Month)    -- Month filter
        ), 0) AS TotalCollected,
        
        -- TotalAdvance: ContractRoomInstallments where Status IN (Advanced, AdvancedPartial)
        -- ✅ UPDATED: Added Month filter
        ISNULL((
            SELECT SUM(cri2.PaidAmount) 
            FROM ContractRoomInstallments cri2
            INNER JOIN ContractRooms cr2 ON cr2.ContractId = cri2.ContractId 
                AND cr2.RoomId = cri2.RoomId 
                AND ISNULL(cr2.IsDeleted, 0) = 0
            WHERE cr2.CampId = ca.Id 
              AND ISNULL(cri2.IsDeleted, 0) = 0
              AND cri2.Status IN ('Advanced', 'AdvancedPartial')
              AND (@Month IS NULL OR cri2.Month = @Month)   -- Month filter
        ), 0) AS TotalAdvance,
        
        -- TotalDue: Balance from ContractRooms
        ISNULL((
            SELECT SUM(cr3.Balance) 
            FROM ContractRooms cr3 
            WHERE cr3.CampId = ca.Id 
              AND cr3.Balance > 0 
              AND cr3.IsDeleted = 0
        ), 0) AS TotalDue,
        
        -- CampExpense: Expenses where Nature='Camp'
        ISNULL((
            SELECT SUM(e.Amount) 
            FROM Expenses e 
            WHERE e.Nature = 'Camp' 
              AND e.CampId = ca.Id 
              AND e.IsDeleted = 0
        ), 0) AS CampExpense,
        
        -- HOAllocated: 10% of HO expenses
        ISNULL((
            SELECT SUM(e2.Amount) * 0.1 
            FROM Expenses e2 
            WHERE e2.Nature = 'HO' 
              AND e2.IsDeleted = 0
        ), 0) AS HOAllocated,
        
        -- Profit: Total Collected - Total Expense
        ISNULL((
            SELECT SUM(cr4.PaidAmount) 
            FROM ContractRooms cr4 
            WHERE cr4.CampId = ca.Id 
              AND cr4.IsDeleted = 0
        ), 0) - 
        ISNULL((
            SELECT SUM(e3.Amount) 
            FROM Expenses e3 
            WHERE e3.Nature = 'Camp' 
              AND e3.CampId = ca.Id 
              AND e3.IsDeleted = 0
        ), 0) AS Profit,
        
        -- TotalExpense: Camp + HO expenses
        ISNULL((
            SELECT SUM(e4.Amount) 
            FROM Expenses e4 
            WHERE (e4.CampId = ca.Id OR e4.Nature = 'HO') 
              AND e4.IsDeleted = 0
        ), 0) AS TotalExpense
        
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId = ca.Id AND r.IsDeleted = 0
    LEFT JOIN ContractCamps cc ON cc.CampId = ca.Id
    LEFT JOIN Contracts c ON c.ContractId = cc.ContractId AND c.IsDeleted = 0
    
    WHERE ca.IsDeleted = 0
      AND (@Status IS NULL OR ca.Status = @Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%' + @SearchText + '%')
    
    GROUP BY ca.Id, ca.Code, ca.Name, ca.Status
    ORDER BY ca.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS 
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

PRINT '✅ Stored Procedure sp_GetCampReport updated with Month filter!';
GO

-- Test the procedure
PRINT 'Testing procedure...';
DECLARE @Total INT;

-- Test without month filter
EXEC sp_GetCampReport 
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
PRINT 'Test 1 - Without month filter: ' + CAST(@Total AS VARCHAR);

-- Test with month filter
EXEC sp_GetCampReport 
    @PageNumber = 1,
    @PageSize = 10,
    @Month = '2026-09',
    @TotalRecords = @Total OUTPUT;
PRINT 'Test 2 - With month filter (2026-09): ' + CAST(@Total AS VARCHAR);
GO

PRINT '✅ Tests complete! Now update the C# code to pass @Month parameter.';
