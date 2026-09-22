-- =============================================
-- MANUAL TEST: Check Everything Right Now
-- Purpose: Test trigger and stored procedure manually
-- Execute: Step by step in SSMS
-- Created: 2026-09-22
-- =============================================

USE [TFMS_SoftwareDB];
GO

PRINT '';
PRINT '========================================';
PRINT '🧪 MANUAL TESTING - START';
PRINT '========================================';
PRINT '';

-- =============================================
-- PART A: TEST TRIGGER
-- =============================================

PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '🔥 PART A: TESTING TRIGGER';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

-- Step A1: Check if trigger exists
PRINT '✓ Step A1: Checking if trigger exists...';
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_ContractRoomsTrns_UpdateRoomStatus')
BEGIN
    PRINT '  ✅ Trigger EXISTS';
    SELECT 
        name AS TriggerName, 
        OBJECT_NAME(parent_id) AS TableName,
        is_disabled AS IsDisabled
    FROM sys.triggers 
    WHERE name = 'trg_ContractRoomsTrns_UpdateRoomStatus';
END
ELSE
BEGIN
    PRINT '  ❌ Trigger NOT FOUND!';
    PRINT '  → Create trigger first!';
END
PRINT '';

-- Step A2: Find a room to test
PRINT '✓ Step A2: Finding a room for testing...';
DECLARE @TestRoomId INT;
DECLARE @TestRoomNo NVARCHAR(50);

-- Get first occupied room
SELECT TOP 1 
    @TestRoomId = Id,
    @TestRoomNo = RoomNo
FROM Rooms
WHERE Occupied = 1 AND ISNULL(IsDeleted, 0) = 0;

IF @TestRoomId IS NOT NULL
BEGIN
    PRINT '  ✅ Test Room Found:';
    PRINT '     RoomId: ' + CAST(@TestRoomId AS NVARCHAR);
    PRINT '     RoomNo: ' + @TestRoomNo;
    
    -- Show current status
    SELECT 
        Id, RoomNo, Status, Occupied, UpdatedAt
    FROM Rooms
    WHERE Id = @TestRoomId;
END
ELSE
BEGIN
    PRINT '  ⚠️ No occupied room found for testing';
    PRINT '  → Trigger test skipped';
END
PRINT '';

-- Step A3: Manual trigger test (optional - shows what trigger would do)
PRINT '✓ Step A3: Trigger logic preview...';
PRINT '  (Trigger will update room automatically on payment)';
PRINT '  To test trigger: Make a payment through API';
PRINT '';

-- =============================================
-- PART B: TEST STORED PROCEDURE
-- =============================================

PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '⏰ PART B: TESTING STORED PROCEDURE';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

-- Step B1: Check if procedure exists
PRINT '✓ Step B1: Checking if procedure exists...';
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_UpdateExpiredContractRooms')
BEGIN
    PRINT '  ✅ Procedure EXISTS';
    SELECT 
        OBJECT_NAME(object_id) AS ProcedureName,
        create_date AS CreatedDate
    FROM sys.procedures
    WHERE name = 'sp_UpdateExpiredContractRooms';
END
ELSE
BEGIN
    PRINT '  ❌ Procedure NOT FOUND!';
    PRINT '  → Run: sp_UpdateExpiredContractRooms_FINAL.sql';
    PRINT '';
    PRINT '  Cannot continue without procedure!';
    GOTO EndTest;
END
PRINT '';

-- Step B2: Preview what procedure will do
PRINT '✓ Step B2: Preview - Rooms with expired contracts...';
SELECT 
    r.Id AS RoomId,
    r.RoomNo,
    r.Status AS CurrentStatus,
    r.Occupied AS CurrentOccupied,
    c.ContractId,
    CONVERT(DATE, c.EndDate) AS ContractEndDate,
    DATEDIFF(DAY, c.EndDate, GETDATE()) AS DaysExpired
FROM Rooms r
CROSS APPLY (
    SELECT TOP 1 
        ct.ContractId, 
        ct.EndDate
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts ct ON ct.ContractId = cri.ContractId
    WHERE cri.RoomId = r.Id
      AND ISNULL(ct.IsDeleted, 0) = 0
      AND ISNULL(cri.IsDeleted, 0) = 0
    ORDER BY ct.EndDate DESC
) c
WHERE 
    r.Occupied = 1
    AND CAST(c.EndDate AS DATE) <= CAST(GETDATE() AS DATE)
    AND ISNULL(r.IsDeleted, 0) = 0;

DECLARE @ExpiredCount INT;
SELECT @ExpiredCount = COUNT(*)
FROM Rooms r
CROSS APPLY (
    SELECT TOP 1 ct.EndDate
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts ct ON ct.ContractId = cri.ContractId
    WHERE cri.RoomId = r.Id
      AND ISNULL(ct.IsDeleted, 0) = 0
    ORDER BY ct.EndDate DESC
) c
WHERE r.Occupied = 1
  AND CAST(c.EndDate AS DATE) <= CAST(GETDATE() AS DATE);

PRINT '';
PRINT '  → ' + CAST(@ExpiredCount AS NVARCHAR) + ' room(s) will be updated';
PRINT '';

-- Step B3: Execute stored procedure
PRINT '✓ Step B3: Executing stored procedure NOW...';
PRINT '';
PRINT '  ⚡ Running: sp_UpdateExpiredContractRooms';
PRINT '';

-- EXECUTE THE PROCEDURE
EXEC sp_UpdateExpiredContractRooms;

PRINT '';
PRINT '  ✅ Procedure executed!';
PRINT '';

-- Step B4: Verify results
PRINT '✓ Step B4: Verification - Rooms updated just now...';
SELECT 
    r.Id AS RoomId,
    r.RoomNo,
    r.Status AS CurrentStatus,
    r.Occupied AS CurrentOccupied,
    r.UpdatedAt AS UpdatedAt,
    DATEDIFF(SECOND, r.UpdatedAt, GETDATE()) AS SecondsAgo
FROM Rooms r
WHERE 
    r.Status = 'Vacant'
    AND r.Occupied = 0
    AND DATEDIFF(MINUTE, r.UpdatedAt, GETDATE()) <= 1  -- Updated in last 1 minute
    AND ISNULL(r.IsDeleted, 0) = 0
ORDER BY r.UpdatedAt DESC;

PRINT '';

-- =============================================
-- PART C: COMPLETE SUMMARY
-- =============================================

PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '📊 PART C: COMPLETE SUMMARY';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

-- Summary statistics
DECLARE @TotalRooms INT;
DECLARE @OccupiedRooms INT;
DECLARE @VacantRooms INT;

SELECT @TotalRooms = COUNT(*) FROM Rooms WHERE ISNULL(IsDeleted, 0) = 0;
SELECT @OccupiedRooms = COUNT(*) FROM Rooms WHERE Occupied = 1 AND ISNULL(IsDeleted, 0) = 0;
SELECT @VacantRooms = COUNT(*) FROM Rooms WHERE Occupied = 0 AND ISNULL(IsDeleted, 0) = 0;

PRINT '📊 Room Statistics:';
PRINT '   Total Rooms: ' + CAST(@TotalRooms AS NVARCHAR);
PRINT '   Occupied: ' + CAST(@OccupiedRooms AS NVARCHAR);
PRINT '   Vacant: ' + CAST(@VacantRooms AS NVARCHAR);
PRINT '';

SELECT 
    'Total Rooms' AS Category,
    @TotalRooms AS Count
UNION ALL
SELECT 'Occupied Rooms', @OccupiedRooms
UNION ALL
SELECT 'Vacant Rooms', @VacantRooms;

PRINT '';

EndTest:

PRINT '';
PRINT '========================================';
PRINT '✅ MANUAL TESTING - COMPLETE';
PRINT '========================================';
PRINT '';
PRINT '📋 What was tested:';
PRINT '   ✓ Trigger existence';
PRINT '   ✓ Stored procedure existence';
PRINT '   ✓ Stored procedure execution';
PRINT '   ✓ Result verification';
PRINT '';
PRINT '📝 Next Steps:';
PRINT '   1. Review results above';
PRINT '   2. Test trigger by making a payment through API';
PRINT '   3. Schedule SQL Job for daily automation (optional)';
PRINT '';
PRINT '🔧 Useful Commands:';
PRINT '   • Run procedure again: EXEC sp_UpdateExpiredContractRooms;';
PRINT '   • Check all vacant: SELECT * FROM Rooms WHERE Status = ''Vacant'';';
PRINT '   • Check all occupied: SELECT * FROM Rooms WHERE Occupied = 1;';
PRINT '';

GO
