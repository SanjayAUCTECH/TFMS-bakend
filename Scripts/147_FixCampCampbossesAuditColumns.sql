-- ============================================================
-- 147: CampCampbosses mein audit columns add karo
--      + IsDeleted filter on GET
-- Date: Aug 3, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── CampCampbosses — audit columns add karo ──────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='IsDeleted')
    ALTER TABLE CampCampbosses ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='AddedBy')
    ALTER TABLE CampCampbosses ADD AddedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='UpdatedBy')
    ALTER TABLE CampCampbosses ADD UpdatedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='DeletedBy')
    ALTER TABLE CampCampbosses ADD DeletedBy INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='CreatedAt')
    ALTER TABLE CampCampbosses ADD CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE();
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='UpdatedAt')
    ALTER TABLE CampCampbosses ADD UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE();
GO
PRINT '✅ CampCampbosses audit columns added';
GO
