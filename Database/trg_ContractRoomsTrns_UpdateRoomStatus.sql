-- =============================================
-- Trigger: Update Rooms Status based on ContractRoomsTrns
-- Table: ContractRoomsTrns
-- Purpose: Automatically update Room Occupied and Status
--          based on latest payment status
-- Created: 2026-09-21
-- =============================================

USE [TFMS_TestSoftwareDB];
GO

-- Drop existing trigger if exists
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_ContractRoomsTrns_UpdateRoomStatus')
BEGIN
    DROP TRIGGER trg_ContractRoomsTrns_UpdateRoomStatus;
    PRINT '🗑️ Existing trigger dropped.';
END
GO

-- Create the trigger
CREATE TRIGGER trg_ContractRoomsTrns_UpdateRoomStatus
ON ContractRoomsTrns
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Collect all affected RoomIds
        DECLARE @AffectedRooms TABLE (
            RoomId INT PRIMARY KEY,
            LatestPaymentStatus NVARCHAR(50),
            LatestRecordId INT
        );
        
        -- Get affected rooms from INSERTED (INSERT/UPDATE operations)
        INSERT INTO @AffectedRooms (RoomId, LatestPaymentStatus, LatestRecordId)
        SELECT DISTINCT i.RoomId, NULL, NULL
        FROM INSERTED i
        WHERE i.RoomId IS NOT NULL;
        
        -- Get affected rooms from DELETED (DELETE operations)
        INSERT INTO @AffectedRooms (RoomId, LatestPaymentStatus, LatestRecordId)
        SELECT DISTINCT d.RoomId, NULL, NULL
        FROM DELETED d
        WHERE d.RoomId IS NOT NULL
          AND d.RoomId NOT IN (SELECT RoomId FROM @AffectedRooms);
        
        -- For each affected room, get the latest payment status (TOP 1 by Id DESC)
        UPDATE @AffectedRooms
        SET LatestPaymentStatus = latest.PaymentStatus,
            LatestRecordId = latest.Id
        FROM @AffectedRooms ar
        CROSS APPLY (
            SELECT TOP 1 
                crt.Id,
                ISNULL(crt.PaymentStatus, '') AS PaymentStatus
            FROM ContractRoomsTrns crt
            WHERE crt.RoomId = ar.RoomId
              AND ISNULL(crt.IsDeleted, 0) = 0
            ORDER BY crt.Id DESC
        ) latest;
        
        -- Update Rooms based on PaymentStatus
        
        -- Case 1: Paid or PaidPartial -> Occupied
        UPDATE r
        SET r.Occupied  = 1,
            r.Status    = 'Occupied',
            r.UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN @AffectedRooms ar ON r.Id = ar.RoomId
        WHERE ar.LatestPaymentStatus IN ('Paid', 'PaidPartial')
          AND ISNULL(r.IsDeleted, 0) = 0;
        
        -- Case 2: Advanced or AdvancedPartial -> Vacant
        UPDATE r
        SET r.Occupied  = 0,
            r.Status    = 'Vacant',
            r.UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN @AffectedRooms ar ON r.Id = ar.RoomId
        WHERE ar.LatestPaymentStatus IN ('Advanced', 'AdvancedPartial')
          AND ISNULL(r.IsDeleted, 0) = 0;
        
        -- Case 3: NULL or any other status -> Vacant
        UPDATE r
        SET r.Occupied  = 0,
            r.Status    = 'Vacant',
            r.UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN @AffectedRooms ar ON r.Id = ar.RoomId
        WHERE (ar.LatestPaymentStatus IS NULL 
               OR ar.LatestPaymentStatus NOT IN ('Paid', 'PaidPartial', 'Advanced', 'AdvancedPartial'))
          AND ISNULL(r.IsDeleted, 0) = 0;
        
        -- Handle case where no records exist for a room (after DELETE all records)
        UPDATE r
        SET r.Occupied  = 0,
            r.Status    = 'Vacant',
            r.UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN @AffectedRooms ar ON r.Id = ar.RoomId
        WHERE ar.LatestRecordId IS NULL
          AND ISNULL(r.IsDeleted, 0) = 0;
          
    END TRY
    BEGIN CATCH
        -- In case of error, log it (optional: create error log table)
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Re-throw the error
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- Verify trigger creation
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_ContractRoomsTrns_UpdateRoomStatus')
BEGIN
    PRINT '✅ Trigger created successfully!';
    PRINT '';
    PRINT 'Trigger Details:';
    
    SELECT 
        t.name AS TriggerName,
        OBJECT_NAME(t.parent_id) AS TableName,
        CASE WHEN t.is_disabled = 0 THEN 'Enabled' ELSE 'Disabled' END AS Status,
        t.create_date AS CreatedDate
    FROM sys.triggers t
    WHERE t.name = 'trg_ContractRoomsTrns_UpdateRoomStatus';
END
ELSE
BEGIN
    PRINT '❌ Trigger creation failed!';
END
GO

PRINT '';
PRINT '================================================';
PRINT 'Trigger Installation Complete!';
PRINT '================================================';
PRINT '';
PRINT 'Now refresh your SSMS Object Explorer:';
PRINT '1. Right-click on "Triggers" folder';
PRINT '2. Click "Refresh"';
PRINT '3. You should see: trg_ContractRoomsTrns_UpdateRoomStatus';
PRINT '';
