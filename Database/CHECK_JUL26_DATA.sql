-- Check Jul26 Data in ContractRoomInstallments
-- Run this to see what data exists for July 2026

USE TFMS_TestSoftwareDB
GO

PRINT '=== Checking Jul26 Data ==='
PRINT ''

-- 1. Check if Jul26 records exist
PRINT '1. Records with Month = Jul26:'
SELECT COUNT(*) AS TotalRecords
FROM ContractRoomInstallments
WHERE Month = 'Jul26'
  AND ISNULL(IsDeleted, 0) = 0
GO

-- 2. Show some sample Jul26 records
PRINT ''
PRINT '2. Sample Jul26 Records:'
SELECT TOP 10
    ContractId,
    CampId,
    RoomNo,
    Month,
    Status,
    InstallAmount,
    PaidAmount,
    DueDate
FROM ContractRoomInstallments
WHERE Month = 'Jul26'
  AND ISNULL(IsDeleted, 0) = 0
ORDER BY ContractId
GO

-- 3. Camp-wise Jul26 Occupancy
PRINT ''
PRINT '3. Camp-wise Jul26 Occupancy:'
SELECT
    c.Name AS CampName,
    COUNT(DISTINCT cri.RoomNo) AS OccupiedRoomsInJul26
FROM Camps c
LEFT JOIN ContractRoomInstallments cri
    ON cri.CampId = c.Id
    AND cri.Month = 'Jul26'
    AND ISNULL(cri.IsDeleted, 0) = 0
    AND cri.RoomNo IS NOT NULL
WHERE c.Status = 'Active'
  AND c.IsDeleted = 0
GROUP BY c.Id, c.Name
ORDER BY c.Name
GO

-- 4. All available months in data
PRINT ''
PRINT '4. All Available Months:'
SELECT DISTINCT Month, COUNT(*) AS RecordCount
FROM ContractRoomInstallments
WHERE ISNULL(IsDeleted, 0) = 0
GROUP BY Month
ORDER BY Month
GO

PRINT ''
PRINT '=== Check Complete ==='
