-- ==============================================================================
-- TFMS Database Backup Feature - Complete Schema
-- ==============================================================================
-- Purpose: Creates all required database objects for Backup feature
-- Date: October 31, 2026
-- Version: 1.0
-- Safe to run multiple times - Idempotent script
-- ==============================================================================
-- 
-- CONTENTS:
-- 1. DatabaseBackups Table
-- 2. Indexes for Performance
-- 3. Sample Data (optional)
-- 
-- ==============================================================================

USE [TFMS_TestSoftwareDB]
GO

SET NOCOUNT ON;
GO

PRINT '=============================================='
PRINT 'TFMS Database Backup Feature Schema Setup'
PRINT 'Started: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '=============================================='
PRINT ''

-- ==============================================================================
-- SECTION 1: Create DatabaseBackups Table
-- ==============================================================================

PRINT '[1/3] Creating DatabaseBackups table...'
PRINT ''

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[DatabaseBackups]
    (
        [Id]         INT            IDENTITY(1,1) NOT NULL,
        [BackupDate] DATETIME       NOT NULL,
        [BackupName] NVARCHAR(100)  NOT NULL,
        [Location]   NVARCHAR(500)  NOT NULL,
        [Remarks]    NVARCHAR(500)  NULL,
        [AddedBy]    NVARCHAR(100)  NULL,
        [CreatedAt]  DATETIME       NOT NULL DEFAULT GETUTCDATE(),
        
        CONSTRAINT [PK_DatabaseBackups] PRIMARY KEY CLUSTERED ([Id] ASC)
    )
    
    PRINT '    ✓ DatabaseBackups table created successfully'
    PRINT ''
END
ELSE
BEGIN
    PRINT '    ℹ DatabaseBackups table already exists (skipping)'
    PRINT ''
END
GO

-- ==============================================================================
-- SECTION 2: Create Indexes for Performance
-- ==============================================================================

PRINT '[2/3] Creating indexes for performance...'
PRINT ''

-- Index on BackupDate for date-based queries
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = 'IX_DatabaseBackups_BackupDate' 
    AND object_id = OBJECT_ID('DatabaseBackups')
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_DatabaseBackups_BackupDate]
    ON [dbo].[DatabaseBackups] ([BackupDate] DESC)
    
    PRINT '    ✓ Index IX_DatabaseBackups_BackupDate created'
END
ELSE
BEGIN
    PRINT '    ℹ Index IX_DatabaseBackups_BackupDate already exists'
END

-- Index on CreatedAt for recent records queries
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = 'IX_DatabaseBackups_CreatedAt' 
    AND object_id = OBJECT_ID('DatabaseBackups')
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_DatabaseBackups_CreatedAt]
    ON [dbo].[DatabaseBackups] ([CreatedAt] DESC)
    
    PRINT '    ✓ Index IX_DatabaseBackups_CreatedAt created'
END
ELSE
BEGIN
    PRINT '    ℹ Index IX_DatabaseBackups_CreatedAt already exists'
END

PRINT ''
GO

-- ==============================================================================
-- SECTION 3: Verify Table Structure
-- ==============================================================================

PRINT '[3/3] Verifying table structure...'
PRINT ''

-- Display column information
SELECT 
    c.COLUMN_NAME AS [Column Name],
    c.DATA_TYPE AS [Data Type],
    CASE WHEN c.IS_NULLABLE = 'YES' THEN 'NULL' ELSE 'NOT NULL' END AS [Nullable],
    ISNULL(CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR), '-') AS [Max Length],
    ISNULL(c.COLUMN_DEFAULT, '-') AS [Default Value]
FROM 
    INFORMATION_SCHEMA.COLUMNS c
WHERE 
    c.TABLE_NAME = 'DatabaseBackups'
ORDER BY 
    c.ORDINAL_POSITION

PRINT ''
PRINT '    ✓ Table structure verified'
PRINT ''

-- Display index information
PRINT '    Indexes:'
SELECT 
    i.name AS [Index Name],
    i.type_desc AS [Type],
    COL_NAME(ic.object_id, ic.column_id) AS [Column]
FROM 
    sys.indexes i
INNER JOIN 
    sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE 
    i.object_id = OBJECT_ID('DatabaseBackups')
ORDER BY 
    i.name, ic.index_column_id

PRINT ''
GO

-- ==============================================================================
-- SECTION 4: Test Operations
-- ==============================================================================

PRINT '[TEST] Testing table operations...'
PRINT ''

BEGIN TRY
    BEGIN TRANSACTION
    
    -- Test INSERT
    DECLARE @TestId INT
    DECLARE @TestBackupName NVARCHAR(100) = 'TEST_Backup_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss')
    
    INSERT INTO [dbo].[DatabaseBackups] 
    (
        BackupDate, 
        BackupName, 
        Location, 
        Remarks, 
        AddedBy, 
        CreatedAt
    )
    VALUES 
    (
        GETDATE(),
        @TestBackupName,
        'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup',
        'Test record - Safe to delete',
        'SYSTEM_TEST',
        GETUTCDATE()
    )
    
    SET @TestId = SCOPE_IDENTITY()
    PRINT '    ✓ INSERT operation successful (Test ID: ' + CAST(@TestId AS VARCHAR) + ')'
    
    -- Test SELECT
    IF EXISTS (SELECT * FROM [dbo].[DatabaseBackups] WHERE Id = @TestId)
    BEGIN
        PRINT '    ✓ SELECT operation successful'
    END
    
    -- Test UPDATE
    UPDATE [dbo].[DatabaseBackups] 
    SET Remarks = 'Test record updated' 
    WHERE Id = @TestId
    
    PRINT '    ✓ UPDATE operation successful'
    
    -- Test DELETE
    DELETE FROM [dbo].[DatabaseBackups] WHERE Id = @TestId
    PRINT '    ✓ DELETE operation successful'
    
    -- Rollback test transaction
    ROLLBACK TRANSACTION
    PRINT '    ✓ Test transaction rolled back (no data persisted)'
    
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION
    
    PRINT '    ✗ Test failed: ' + ERROR_MESSAGE()
END CATCH

PRINT ''
GO

-- ==============================================================================
-- SECTION 5: Summary
-- ==============================================================================

PRINT '=============================================='
PRINT 'SCHEMA SETUP SUMMARY'
PRINT '=============================================='

DECLARE @TableExists BIT = 0
DECLARE @IndexCount INT = 0

-- Check if table exists
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND type = N'U')
    SET @TableExists = 1

-- Count indexes
SELECT @IndexCount = COUNT(*) 
FROM sys.indexes 
WHERE object_id = OBJECT_ID('DatabaseBackups') 
AND name IS NOT NULL

IF @TableExists = 1 AND @IndexCount >= 2
BEGIN
    PRINT '✅ SUCCESS: All database objects created'
    PRINT ''
    PRINT 'Created Objects:'
    PRINT '  ✓ DatabaseBackups table'
    PRINT '  ✓ Primary key constraint'
    PRINT '  ✓ ' + CAST(@IndexCount AS VARCHAR) + ' indexes'
    PRINT ''
    PRINT 'Next Steps:'
    PRINT '  1. Deploy backend application'
    PRINT '  2. Deploy frontend application'
    PRINT '  3. Test backup creation'
    PRINT '  4. Test backup download'
    PRINT ''
    PRINT '✅ Database is ready for Backup feature!'
END
ELSE
BEGIN
    PRINT '⚠ WARNING: Schema setup incomplete'
    PRINT ''
    PRINT 'Issues detected:'
    IF @TableExists = 0
        PRINT '  ✗ DatabaseBackups table not found'
    IF @IndexCount < 2
        PRINT '  ✗ Missing indexes (found ' + CAST(@IndexCount AS VARCHAR) + ', expected 2+)'
    PRINT ''
    PRINT 'Action required: Review error messages above'
END

PRINT ''
PRINT 'Completed: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '=============================================='
GO

-- ==============================================================================
-- SECTION 6: Current Data Summary
-- ==============================================================================

PRINT ''
PRINT 'Current Database Backups:'
PRINT '--------------------------'

DECLARE @RecordCount INT
SELECT @RecordCount = COUNT(*) FROM [dbo].[DatabaseBackups]

IF @RecordCount > 0
BEGIN
    PRINT 'Total backup records: ' + CAST(@RecordCount AS VARCHAR)
    PRINT ''
    PRINT 'Latest 5 backups:'
    
    SELECT TOP 5
        Id AS [ID],
        BackupName AS [Backup Name],
        BackupDate AS [Date],
        AddedBy AS [Created By]
    FROM 
        [dbo].[DatabaseBackups]
    ORDER BY 
        CreatedAt DESC
END
ELSE
BEGIN
    PRINT 'No backup records found (This is normal for new installation)'
END

PRINT ''
GO

-- ==============================================================================
-- END OF SCRIPT
-- ==============================================================================

PRINT '=============================================='
PRINT 'Script execution completed!'
PRINT '=============================================='
GO

SET NOCOUNT OFF;
GO

/*
================================================================================
NOTES:
================================================================================

1. TABLE STRUCTURE:
   - Id: Primary key, auto-increment
   - BackupDate: When backup was created
   - BackupName: Name without .bak extension (e.g., TFMS_Backup_20261031_114555)
   - Location: Server path where .bak file is stored
   - Remarks: Optional notes about the backup
   - AddedBy: Username who created the backup
   - CreatedAt: Record creation timestamp (UTC)

2. INDEXES:
   - IX_DatabaseBackups_BackupDate: Optimizes date-based queries
   - IX_DatabaseBackups_CreatedAt: Optimizes recent records queries

3. NO STORED PROCEDURES:
   - This feature uses inline SQL queries (not stored procedures)
   - All logic is in C# application code

4. DEPENDENCIES:
   - None - This is a standalone feature
   - No foreign keys to other tables
   - No triggers required

5. SECURITY:
   - Table accessible to application service account
   - No special permissions required beyond standard DB access
   - File operations use SQL Server service account

6. MAINTENANCE:
   - Consider implementing backup file cleanup policy
   - Monitor table growth (one row per backup)
   - Regular index maintenance recommended

7. COMPATIBILITY:
   - SQL Server 2016 or later
   - Works with SQL Express and Standard editions
   - Compatible with SQL Server 2019, 2022

================================================================================
*/
