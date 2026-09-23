-- Test Dashboard Stats for July 2026
-- Run this in SQL Server Management Studio

-- Connection Info:
-- Server: 160.25.62.124,1433
-- Database: TFMS_TestSoftwareDB
-- User: tfms_user
-- Password: tfms@123

USE TFMS_TestSoftwareDB
GO

PRINT '=== Testing Dashboard Stats for July 2026 ==='
PRINT ''

-- 1. Get Procedure Definition
PRINT '1. Stored Procedure Definition:'
PRINT '================================'
EXEC sp_helptext 'sp_GetDashboardStats'
GO

PRINT ''
PRINT '2. Execute Procedure for July 2026:'
PRINT '===================================='

-- Execute the stored procedure for July 2026
EXEC sp_GetDashboardStats 
    @CampId = NULL,
    @TenantId = NULL,
    @Year = 2026,
    @Month = 7
GO

PRINT ''
PRINT '3. Camp Occupancy (Direct Query):'
PRINT '=================================='

-- This is the query used for campOccupancy in the API
SELECT 
    c.Name AS CampName,
    COUNT(r.Id) AS TotalRooms,
    SUM(CASE WHEN r.Status='Occupied' THEN 1 ELSE 0 END) AS Occupied,
    SUM(CASE WHEN r.Status='Vacant' THEN 1 ELSE 0 END) AS Vacant 
FROM Camps c 
LEFT JOIN Rooms r ON r.CampId = c.Id AND r.IsDeleted = 0 
WHERE c.Status = 'Active' AND c.IsDeleted = 0 
GROUP BY c.Id, c.Name 
ORDER BY c.Name
GO

PRINT ''
PRINT '4. Check if sp_GetDashboardStats exists:'
PRINT '========================================'

SELECT 
    OBJECT_NAME(object_id) AS ProcedureName,
    create_date,
    modify_date
FROM sys.procedures 
WHERE name = 'sp_GetDashboardStats'
GO

PRINT ''
PRINT '=== Test Complete ==='
