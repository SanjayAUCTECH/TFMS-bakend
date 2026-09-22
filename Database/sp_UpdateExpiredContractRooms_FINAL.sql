-- =============================================
-- Stored Procedure: Update Room Status for Expired Contracts
-- Purpose: Automatically mark rooms as Vacant when contract expires
-- Version: FINAL (Minimal & Guaranteed to Work)
-- Created: 2026-09-22
-- =============================================

USE [TFMS_SoftwareDB];
GO

-- Drop existing procedure if exists
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_UpdateExpiredContractRooms')
BEGIN
    DROP PROCEDURE sp_UpdateExpiredContractRooms;
END
GO

CREATE PROCEDURE [dbo].[sp_UpdateExpiredContractRooms]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @UpdatedRooms INT = 0;
    
    BEGIN TRY
        
        -- =============================================
        -- Update Rooms with Expired Contracts
        -- =============================================
        UPDATE r
        SET r.Occupied  = 0,
            r.Status    = 'Vacant',
            r.UpdatedAt = GETDATE()
        FROM Rooms r
        CROSS APPLY (
            -- Get LATEST contract for this room
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
            -- Contract EXPIRED: EndDate <= TODAY
            CAST(lastContract.EndDate AS DATE) <= CAST(GETDATE() AS DATE)
            -- Room currently Occupied
            AND r.Occupied = 1
            -- Room not deleted
            AND ISNULL(r.IsDeleted, 0) = 0
            -- Contract Active or Expired status
            AND lastContract.ContractStatus IN ('Active', 'Expired');
        
        SET @UpdatedRooms = @@ROWCOUNT;
        
        -- =============================================
        -- Return Summary
        -- =============================================
        SELECT 
            @UpdatedRooms AS RoomsUpdated,
            GETDATE() AS ProcessedAt,
            'SUCCESS' AS Status;
        
    END TRY
    BEGIN CATCH
        -- Return error
        SELECT 
            0 AS RoomsUpdated,
            GETDATE() AS ProcessedAt,
            'ERROR' AS Status,
            ERROR_MESSAGE() AS ErrorMessage;
        
        THROW;
    END CATCH
END;
GO

-- =============================================
-- Verify Creation
-- =============================================
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_UpdateExpiredContractRooms')
BEGIN
    PRINT '';
    PRINT '========================================';
    PRINT '✅ SUCCESS!';
    PRINT '========================================';
    PRINT '';
    PRINT 'Procedure: sp_UpdateExpiredContractRooms';
    PRINT 'Database: TFMS_SoftwareDB';
    PRINT 'Status: Created successfully';
    PRINT '';
    PRINT 'Test it now:';
    PRINT '  EXEC sp_UpdateExpiredContractRooms;';
    PRINT '';
    PRINT 'What it does:';
    PRINT '  ✓ Finds rooms with expired contracts';
    PRINT '  ✓ Updates: Occupied=0, Status=Vacant';
    PRINT '  ✓ Returns: Count of updated rooms';
    PRINT '';
    PRINT '========================================';
    PRINT '';
END
ELSE
BEGIN
    PRINT '❌ FAILED - See errors above';
END
GO
