-- =============================================
-- Stored Procedure: Update Room Status for Expired Contracts
-- Purpose: Automatically mark rooms as Vacant when contract expires
-- Schedule: Run daily via SQL Server Agent Job
-- Created: 2026-09-21
-- =============================================

USE [TFMS_SoftwareDB];
GO

-- Drop existing procedure if exists
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_UpdateExpiredContractRooms')
BEGIN
    DROP PROCEDURE sp_UpdateExpiredContractRooms;
    PRINT '🗑️ Existing procedure dropped.';
END
GO

CREATE PROCEDURE [dbo].[sp_UpdateExpiredContractRooms]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProcessedRooms INT = 0;
    DECLARE @UpdatedRooms INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);
    
    BEGIN TRY
        -- Create temp table to store rooms with expired contracts
        CREATE TABLE #ExpiredContractRooms (
            RoomId INT,
            RoomNo NVARCHAR(50),
            ContractId NVARCHAR(50),
            ContractEndDate DATETIME,
            CurrentStatus NVARCHAR(50),
            DaysExpired INT
        );
        
        -- =============================================
        -- Step 1: Find all rooms with expired contracts
        -- =============================================
        -- Logic: Get LATEST contract per room from ContractRoomInstallments
        --        Check if contract EndDate <= TODAY
        -- =============================================
        
        INSERT INTO #ExpiredContractRooms (
            RoomId, RoomNo, 
            ContractId, ContractEndDate, 
            CurrentStatus, DaysExpired
        )
        SELECT DISTINCT
            r.Id AS RoomId,
            r.RoomNo,
            lastContract.ContractId,
            lastContract.EndDate AS ContractEndDate,
            r.Status AS CurrentStatus,
            DATEDIFF(DAY, lastContract.EndDate, GETDATE()) AS DaysExpired
        FROM Rooms r
        -- Get the LATEST contract for each room
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
            -- Contract has EXPIRED (EndDate is today or before today)
            CAST(lastContract.EndDate AS DATE) <= CAST(GETDATE() AS DATE)
            -- Room is currently marked as Occupied (needs to be changed)
            AND r.Occupied = 1
            -- Room is not deleted
            AND ISNULL(r.IsDeleted, 0) = 0
            -- Contract status is Active or Expired (not already Cancelled)
            AND lastContract.ContractStatus IN ('Active', 'Expired');
        
        SET @ProcessedRooms = @@ROWCOUNT;
        
        -- =============================================
        -- Step 2: Update Rooms table to Vacant
        -- =============================================
        
        UPDATE r
        SET r.Occupied  = 0,
            r.Status    = 'Vacant',
            r.UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN #ExpiredContractRooms ecr ON ecr.RoomId = r.Id;
        
        SET @UpdatedRooms = @@ROWCOUNT;
        
        -- =============================================
        -- Step 3: Log the changes (optional - create log table if needed)
        -- =============================================
        
        -- Uncomment this section if you want to log changes
        /*
        IF OBJECT_ID('RoomStatusChangeLog', 'U') IS NOT NULL
        BEGIN
            INSERT INTO RoomStatusChangeLog (
                RoomId, RoomNo, CampId, CampName, 
                ContractId, ContractEndDate, 
                OldStatus, NewStatus, DaysExpired, 
                ChangedBy, ChangeReason, ChangedAt
            )
            SELECT 
                RoomId, RoomNo, CampId, CampName,
                ContractId, ContractEndDate,
                CurrentStatus, 'Vacant', DaysExpired,
                'SYSTEM', 'Contract Expired', GETDATE()
            FROM #ExpiredContractRooms;
        END
        */
        
        -- =============================================
        -- Step 4: Return summary
        -- =============================================
        
        SELECT 
            @ProcessedRooms AS RoomsFound,
            @UpdatedRooms AS RoomsUpdated,
            GETDATE() AS ProcessedAt,
            'SUCCESS' AS Status;
        
        -- Return details of updated rooms
        SELECT 
            RoomId,
            RoomNo,
            ContractId,
            ContractEndDate,
            CurrentStatus AS OldStatus,
            'Vacant' AS NewStatus,
            DaysExpired
        FROM #ExpiredContractRooms
        ORDER BY DaysExpired DESC, RoomNo;
        
        -- Cleanup
        DROP TABLE #ExpiredContractRooms;
        
    END TRY
    BEGIN CATCH
        -- Error handling
        SET @ErrorMessage = ERROR_MESSAGE();
        
        -- Cleanup temp table if exists
        IF OBJECT_ID('tempdb..#ExpiredContractRooms') IS NOT NULL
            DROP TABLE #ExpiredContractRooms;
        
        -- Return error details
        SELECT 
            0 AS RoomsFound,
            0 AS RoomsUpdated,
            GETDATE() AS ProcessedAt,
            'ERROR' AS Status,
            @ErrorMessage AS ErrorMessage;
        
        -- Re-throw error
        THROW;
    END CATCH
END;
GO

-- =============================================
-- Verify procedure creation
-- =============================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_UpdateExpiredContractRooms')
BEGIN
    PRINT '';
    PRINT '✅ Stored Procedure created successfully!';
    PRINT '';
    PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    PRINT 'Procedure: sp_UpdateExpiredContractRooms';
    PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    PRINT '';
    PRINT '📋 What it does:';
    PRINT '   ✓ Finds all rooms with expired contracts';
    PRINT '   ✓ Checks contract EndDate <= TODAY';
    PRINT '   ✓ Updates room to Occupied = 0, Status = Vacant';
    PRINT '   ✓ Returns list of updated rooms';
    PRINT '';
    PRINT '🔧 How to test (Manual):';
    PRINT '   EXEC sp_UpdateExpiredContractRooms;';
    PRINT '';
    PRINT '⏰ How to schedule (Automatic Daily):';
    PRINT '   1. Create SQL Server Agent Job';
    PRINT '   2. Schedule: Daily at 12:00 AM';
    PRINT '   3. Action: EXEC sp_UpdateExpiredContractRooms;';
    PRINT '';
    PRINT '📊 Procedure Details:';
    
    SELECT 
        OBJECT_NAME(object_id) AS ProcedureName,
        create_date AS CreatedDate,
        modify_date AS ModifiedDate
    FROM sys.procedures
    WHERE name = 'sp_UpdateExpiredContractRooms';
    
    PRINT '';
    PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END
ELSE
BEGIN
    PRINT '❌ Procedure creation failed!';
END
GO

-- =============================================
-- Optional: Create Log Table for Tracking Changes
-- =============================================

PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Optional: Create Log Table';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT 'Uncomment below section to create change log table:';
PRINT '';

/*
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RoomStatusChangeLog')
BEGIN
    CREATE TABLE RoomStatusChangeLog (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        RoomId INT NOT NULL,
        RoomNo NVARCHAR(50),
        CampId INT,
        CampName NVARCHAR(200),
        ContractId NVARCHAR(50),
        ContractEndDate DATETIME,
        OldStatus NVARCHAR(50),
        NewStatus NVARCHAR(50),
        DaysExpired INT,
        ChangedBy NVARCHAR(100),
        ChangeReason NVARCHAR(500),
        ChangedAt DATETIME DEFAULT GETDATE()
    );
    
    PRINT '✅ RoomStatusChangeLog table created!';
    PRINT '   This table will track all room status changes.';
    PRINT '   Uncomment logging code in stored procedure to use it.';
END
ELSE
BEGIN
    PRINT '✓ RoomStatusChangeLog table already exists.';
END
GO
*/

PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✅ Setup Complete!';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT '⚠️ IMPORTANT: This procedure is created but NOT scheduled.';
PRINT '   You can execute it manually anytime.';
PRINT '   To automate, create a SQL Server Agent Job.';
PRINT '';
