-- ============================================================
-- 085: Add Audit Columns to tables missed by script 070
--      Tables: Roles, RoomStatuses
--      Columns: AddedBy INT NULL
--               UpdatedBy INT NULL
--               DeletedBy INT NULL
--               IsDeleted BIT NOT NULL DEFAULT 0
-- Date: July 25, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Roles ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Roles') AND name='AddedBy')
    ALTER TABLE Roles ADD AddedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Roles') AND name='UpdatedBy')
    ALTER TABLE Roles ADD UpdatedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Roles') AND name='DeletedBy')
    ALTER TABLE Roles ADD DeletedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Roles') AND name='IsDeleted')
    ALTER TABLE Roles ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO
-- Ensure existing rows are marked as not deleted
UPDATE Roles SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO
PRINT 'Roles — AddedBy, UpdatedBy, DeletedBy, IsDeleted added';
GO

-- ── RoomStatuses ───────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('RoomStatuses') AND name='AddedBy')
    ALTER TABLE RoomStatuses ADD AddedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('RoomStatuses') AND name='UpdatedBy')
    ALTER TABLE RoomStatuses ADD UpdatedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('RoomStatuses') AND name='DeletedBy')
    ALTER TABLE RoomStatuses ADD DeletedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('RoomStatuses') AND name='IsDeleted')
    ALTER TABLE RoomStatuses ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO
-- Ensure existing rows are marked as not deleted
UPDATE RoomStatuses SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO
PRINT 'RoomStatuses — AddedBy, UpdatedBy, DeletedBy, IsDeleted added';
GO

PRINT '085 - Audit columns added to Roles and RoomStatuses';
GO
