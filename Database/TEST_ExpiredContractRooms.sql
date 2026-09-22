-- =============================================
-- TEST SCRIPT: Expired Contract Rooms
-- Purpose: Check and verify sp_UpdateExpiredContractRooms
-- Created: 2026-09-22
-- =============================================

USE [TFMS_SoftwareDB];
GO

PRINT '';
PRINT '========================================';
PRINT '🧪 TESTING: Expired Contract Rooms';
PRINT '========================================';
PRINT '';

-- =============================================
-- TEST 1: Check if Procedure Exists
-- =============================================

PRINT '📋 TEST 1: Checking if procedure exists...';
PRINT '';

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_UpdateExpiredContractRooms')
BEGIN
    PRINT '✅ Procedure EXISTS';
    
    SELECT 
        OBJECT_NAME(object_id) AS ProcedureName,
        create_date AS CreatedDate,
        modify_date AS ModifiedDate
    FROM sys.procedures
    WHERE name = 'sp_UpdateExpiredContractRooms';
END
ELSE
BEGIN
    PRINT '❌ Procedure NOT FOUND!';
    PRINT 'Please run: sp_UpdateExpiredContractRooms_FINAL.sql';
    PRINT '';
END

PRINT '';
PRINT '========================================';

-- =============================================
-- TEST 2: Preview - Which Rooms Will Be Affected?
-- =============================================

PRINT '';
PRINT '📋 TEST 2: Preview rooms that will be affected...';
PRINT '';

SELECT 
    r.Id AS RoomId,
    r.RoomNo,
    r.Status AS CurrentStatus,
    r.Occupied AS CurrentOccupied,
    lastContract.ContractId,
    CONVERT(DATE, lastContract.EndDate) AS ContractEndDate,
    lastContract.ContractStatus,
    DATEDIFF(DAY, lastContract.EndDate, GETDATE()) AS DaysExpired,
    CASE 
        WHEN CAST(lastContract.EndDate AS DATE) <= CAST(GETDATE() AS DATE) 
        THEN '🔄 WILL UPDATE TO VACANT'
        ELSE '✓ No change'
    END AS WhatWillHappen
FROM Rooms r
CROSS APPLY (
    SELECT TOP 1
        c.ContractId,
        c.EndDate,
        c.Status AS ContractStatus
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON c.ContractId = cri.ContractId
    WHERE cri.RoomId = r.Id
      AND ISNULL(c.IsDeleted, 0) = 0
      AND ISNULL(cri.IsDeleted, 0) = 0
    ORDER BY c.EndDate DESC, c.CreatedAt DESC
) lastContract
WHERE 
    r.Occupied = 1
    AND ISNULL(r.IsDeleted, 0) = 0
    AND lastContract.ContractStatus IN ('Active', 'Expired')
ORDER BY lastContract.EndDate;

PRINT '';
PRINT '👆 Above rooms will be marked as VACANT if EndDate <= TODAY';
PRINT '';
PRINT '========================================';

-- =============================================
-- TEST 3: Count Summary
-- =============================================

PRINT '';
PRINT '📋 TEST 3: Summary of what will happen...';
PRINT '';

DECLARE @TotalOccupied INT;
DECLARE @WillBeVacant INT;

SELECT @TotalOccupied = COUNT(*)
FROM Rooms
WHERE Occupied = 1 AND ISNULL(IsDeleted, 0) = 0;

SELECT @WillBeVacant = COUNT(*)
FROM Rooms r
CROSS APPLY (
    SELECT TOP 1
        c.EndDate,
        c.Status AS ContractStatus
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON c.ContractId = cri.ContractId
    WHERE cri.RoomId = r.Id
      AND ISNULL(c.IsDeleted, 0) = 0
      AND ISNULL(cri.IsDeleted, 0) = 0
    ORDER BY c.EndDate DESC, c.CreatedAt DESC
) lastContract
WHERE 
    r.Occupied = 1
    AND ISNULL(r.IsDeleted, 0) = 0
    AND CAST(lastContract.EndDate AS DATE) <= CAST(GETDATE() AS DATE)
    AND lastContract.ContractStatus IN ('Active', 'Expired');

SELECT 
    @TotalOccupied AS TotalOccupiedRooms,
    @WillBeVacant AS RoomsWithExpiredContracts,
    (@TotalOccupied - @WillBeVacant) AS WillRemainOccupied,
    GETDATE() AS CheckedAt;

PRINT '';
PRINT 'Summary:';
PRINT '  • Total Occupied Rooms: ' + CAST(@TotalOccupied AS NVARCHAR(10));
PRINT '  • Will be marked Vacant: ' + CAST(@WillBeVacant AS NVARCHAR(10));
PRINT '  • Will remain Occupied: ' + CAST((@TotalOccupied - @WillBeVacant) AS NVARCHAR(10));
PRINT '';
PRINT '========================================';

-- =============================================
-- TEST 4: Detailed Contract Analysis
-- =============================================

PRINT '';
PRINT '📋 TEST 4: Detailed contract expiry analysis...';
PRINT '';

SELECT 
    CASE 
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 30 THEN '❌ Expired >30 days ago'
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 7 THEN '⚠️ Expired 7-30 days ago'
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 0 THEN '⚠️ Expired <7 days ago'
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) = 0 THEN '⏰ Expires TODAY'
        ELSE '✅ Future expiry'
    END AS ExpiryStatus,
    COUNT(*) AS RoomCount
FROM Rooms r
CROSS APPLY (
    SELECT TOP 1
        c.EndDate
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON c.ContractId = cri.ContractId
    WHERE cri.RoomId = r.Id
      AND ISNULL(c.IsDeleted, 0) = 0
      AND ISNULL(cri.IsDeleted, 0) = 0
    ORDER BY c.EndDate DESC, c.CreatedAt DESC
) c
WHERE 
    r.Occupied = 1
    AND ISNULL(r.IsDeleted, 0) = 0
GROUP BY 
    CASE 
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 30 THEN '❌ Expired >30 days ago'
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 7 THEN '⚠️ Expired 7-30 days ago'
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 0 THEN '⚠️ Expired <7 days ago'
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) = 0 THEN '⏰ Expires TODAY'
        ELSE '✅ Future expiry'
    END
ORDER BY 
    CASE 
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 30 THEN 1
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 7 THEN 2
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) > 0 THEN 3
        WHEN DATEDIFF(DAY, c.EndDate, GETDATE()) = 0 THEN 4
        ELSE 5
    END;

PRINT '';
PRINT '========================================';

-- =============================================
-- TEST 5: Ready to Execute?
-- =============================================

PRINT '';
PRINT '📋 TEST 5: Are you ready to execute?';
PRINT '';
PRINT '⚠️ WARNING: This will UPDATE room statuses!';
PRINT '';
PRINT 'If you want to proceed, run this command:';
PRINT '';
PRINT '  EXEC sp_UpdateExpiredContractRooms;';
PRINT '';
PRINT 'Or uncomment the line below to execute now:';
PRINT '';

-- Uncomment to execute immediately
-- EXEC sp_UpdateExpiredContractRooms;

PRINT '';
PRINT '========================================';
PRINT '✅ Testing Complete!';
PRINT '========================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '  1. Review the results above';
PRINT '  2. If everything looks good, execute:';
PRINT '     EXEC sp_UpdateExpiredContractRooms;';
PRINT '  3. Verify results with TEST 6 (below)';
PRINT '';

-- =============================================
-- TEST 6: After Execution - Verify Results
-- =============================================

PRINT '';
PRINT '========================================';
PRINT '📋 TEST 6: Run this AFTER execution';
PRINT '========================================';
PRINT '';
PRINT 'Uncomment and run after executing procedure:';
PRINT '';

/*
-- TEST 6: Verify what was updated
SELECT 
    r.Id AS RoomId,
    r.RoomNo,
    r.Status AS CurrentStatus,
    r.Occupied AS CurrentOccupied,
    r.UpdatedAt AS LastUpdated,
    CASE 
        WHEN CAST(r.UpdatedAt AS DATE) = CAST(GETDATE() AS DATE) 
        THEN '✅ Updated TODAY'
        ELSE '❌ Old data'
    END AS UpdateStatus
FROM Rooms r
WHERE 
    r.Status = 'Vacant'
    AND r.Occupied = 0
    AND CAST(r.UpdatedAt AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY r.UpdatedAt DESC;

PRINT 'Rooms updated to Vacant today (shown above)';
*/

GO
