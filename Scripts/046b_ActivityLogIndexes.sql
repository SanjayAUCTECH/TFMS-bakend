-- ============================================================
-- 046b: ActivityLog Indexes fix
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ActivityLogs_CreatedAt' AND object_id=OBJECT_ID('ActivityLogs'))
    CREATE INDEX IX_ActivityLogs_CreatedAt    ON ActivityLogs (CreatedAt DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ActivityLogs_UserId' AND object_id=OBJECT_ID('ActivityLogs'))
    CREATE INDEX IX_ActivityLogs_UserId       ON ActivityLogs (UserId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ActivityLogs_ActivityType' AND object_id=OBJECT_ID('ActivityLogs'))
    CREATE INDEX IX_ActivityLogs_ActivityType ON ActivityLogs (ActivityType);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ActivityLogs_Module' AND object_id=OBJECT_ID('ActivityLogs'))
    CREATE INDEX IX_ActivityLogs_Module       ON ActivityLogs (Module);
GO

PRINT '046b - ActivityLog indexes created.';
GO
