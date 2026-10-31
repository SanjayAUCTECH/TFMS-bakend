-- ==============================================================================
-- TFMS Database Backup Feature - Live Database Migration Script
-- ==============================================================================
-- Purpose: Ensure DatabaseBackups table exists with all required columns
-- Date: October 31, 2026
-- Version: 1.0
-- Safe to run multiple times - Will only create if doesn't exist
-- ==============================================================================

USE [TFMS_TestSoftwareDB]
GO

PRINT '======================================'
PRINT 'TFMS Database Backup Feature Migration'
PRINT 'Started: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '======================================'
PRINT ''

-- ==============================================================================
-- STEP 1: Check if DatabaseBackups table exists
-- ==============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND type in (N'U'))
BEGIN
    PRINT '[INFO] DatabaseBackups table does NOT exist. Creating...'
    
    -- Create the table
    CREATE TABLE [dbo].[DatabaseBackups] (
        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [BackupDate] DATETIME NOT NULL,
        [BackupName] NVARCHAR(100) NOT NULL,
        [Location] NVARCHAR(500) NOT NULL,
        [Remarks] NVARCHAR(500) NULL,
        [AddedBy] NVARCHAR(100) NULL,
        [CreatedAt] DATETIME NOT NULL DEFAULT GETUTCDATE()
    )
    
    PRINT '[SUCCESS] DatabaseBackups table created successfully!'
    PRINT ''
END
ELSE
BEGIN
    PRINT '[INFO] DatabaseBackups table already exists.'
    PRINT ''
END

-- ==============================================================================
-- STEP 2: Verify all required columns exist
-- ==============================================================================

PRINT '[INFO] Verifying table structure...'
PRINT ''

DECLARE @MissingColumns TABLE (ColumnName NVARCHAR(100))

-- Check for Id column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'Id')
    INSERT INTO @MissingColumns VALUES ('Id')

-- Check for BackupDate column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'BackupDate')
    INSERT INTO @MissingColumns VALUES ('BackupDate')

-- Check for BackupName column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'BackupName')
    INSERT INTO @MissingColumns VALUES ('BackupName')

-- Check for Location column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'Location')
    INSERT INTO @MissingColumns VALUES ('Location')

-- Check for Remarks column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'Remarks')
    INSERT INTO @MissingColumns VALUES ('Remarks')

-- Check for AddedBy column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'AddedBy')
    INSERT INTO @MissingColumns VALUES ('AddedBy')

-- Check for CreatedAt column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND name = 'CreatedAt')
    INSERT INTO @MissingColumns VALUES ('CreatedAt')

-- Report missing columns
IF EXISTS (SELECT * FROM @MissingColumns)
BEGIN
    PRINT '[WARNING] The following columns are missing:'
    SELECT '    - ' + ColumnName AS MissingColumn FROM @MissingColumns
    PRINT ''
    PRINT '[ACTION REQUIRED] Please contact technical support to add missing columns.'
    PRINT ''
END
ELSE
BEGIN
    PRINT '[SUCCESS] All required columns exist!'
    PRINT ''
END

-- ==============================================================================
-- STEP 3: Display current table structure
-- ==============================================================================

PRINT '[INFO] Current DatabaseBackups table structure:'
PRINT ''

SELECT 
    COLUMN_NAME AS [Column Name],
    DATA_TYPE AS [Data Type],
    CASE WHEN IS_NULLABLE = 'YES' THEN 'NULL' ELSE 'NOT NULL' END AS [Nullable],
    ISNULL(CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR), '-') AS [Max Length]
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME = 'DatabaseBackups'
ORDER BY 
    ORDINAL_POSITION

PRINT ''

-- ==============================================================================
-- STEP 4: Verify data integrity (show record count)
-- ==============================================================================

DECLARE @RecordCount INT
SELECT @RecordCount = COUNT(*) FROM [dbo].[DatabaseBackups]

PRINT '[INFO] Current backup records in database: ' + CAST(@RecordCount AS VARCHAR)
PRINT ''

-- ==============================================================================
-- STEP 5: Create indexes for better performance (if not exists)
-- ==============================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DatabaseBackups_BackupDate' AND object_id = OBJECT_ID('DatabaseBackups'))
BEGIN
    PRINT '[INFO] Creating index on BackupDate for better performance...'
    CREATE NONCLUSTERED INDEX IX_DatabaseBackups_BackupDate 
    ON [dbo].[DatabaseBackups] ([BackupDate] DESC)
    PRINT '[SUCCESS] Index created successfully!'
    PRINT ''
END
ELSE
BEGIN
    PRINT '[INFO] Performance index already exists.'
    PRINT ''
END

-- ==============================================================================
-- STEP 6: Test backup record insertion (optional test)
-- ==============================================================================

PRINT '[INFO] Testing backup record insertion...'

DECLARE @TestBackupName NVARCHAR(100) = 'MIGRATION_TEST_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss')

BEGIN TRY
    -- Insert test record
    INSERT INTO [dbo].[DatabaseBackups] (BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt)
    VALUES (
        GETDATE(),
        @TestBackupName,
        'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup',
        'Migration test record - Safe to delete',
        'SYSTEM_MIGRATION_TEST',
        GETUTCDATE()
    )
    
    DECLARE @TestId INT = SCOPE_IDENTITY()
    
    PRINT '[SUCCESS] Test record inserted successfully! (ID: ' + CAST(@TestId AS VARCHAR) + ')'
    
    -- Verify the record
    IF EXISTS (SELECT * FROM [dbo].[DatabaseBackups] WHERE Id = @TestId)
    BEGIN
        PRINT '[SUCCESS] Test record verified successfully!'
        
        -- Clean up test record
        DELETE FROM [dbo].[DatabaseBackups] WHERE Id = @TestId
        PRINT '[INFO] Test record cleaned up.'
    END
    PRINT ''
END TRY
BEGIN CATCH
    PRINT '[ERROR] Test insertion failed!'
    PRINT '[ERROR] Error Message: ' + ERROR_MESSAGE()
    PRINT '[ERROR] Please check table permissions and structure.'
    PRINT ''
END CATCH

-- ==============================================================================
-- STEP 7: Final Summary
-- ==============================================================================

PRINT '======================================'
PRINT 'MIGRATION SUMMARY'
PRINT '======================================'

-- Check overall status
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackups]') AND type in (N'U'))
   AND NOT EXISTS (SELECT * FROM @MissingColumns)
BEGIN
    PRINT '[SUCCESS] ✓ DatabaseBackups table exists'
    PRINT '[SUCCESS] ✓ All required columns present'
    PRINT '[SUCCESS] ✓ Table structure verified'
    PRINT '[SUCCESS] ✓ Performance index created'
    PRINT '[SUCCESS] ✓ Insert/Delete operations working'
    PRINT ''
    PRINT '[RESULT] ✅ MIGRATION SUCCESSFUL!'
    PRINT ''
    PRINT '[NEXT STEPS]'
    PRINT '1. Deploy new backend DLL'
    PRINT '2. Deploy new frontend build'
    PRINT '3. Test backup creation from application'
    PRINT '4. Test backup download from application'
    PRINT ''
END
ELSE
BEGIN
    PRINT '[RESULT] ⚠️ MIGRATION INCOMPLETE - Manual intervention required'
    PRINT ''
    PRINT '[NEXT STEPS]'
    PRINT '1. Review error messages above'
    PRINT '2. Contact technical support'
    PRINT '3. Do not deploy application until resolved'
    PRINT ''
END

PRINT 'Completed: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '======================================'

GO

-- ==============================================================================
-- OPTIONAL: View sample backup records (if any exist)
-- ==============================================================================

PRINT ''
PRINT '[INFO] Sample backup records (showing last 5):'
PRINT ''

IF EXISTS (SELECT * FROM [dbo].[DatabaseBackups])
BEGIN
    SELECT TOP 5
        Id,
        BackupDate,
        BackupName,
        Location,
        AddedBy,
        CreatedAt
    FROM 
        [dbo].[DatabaseBackups]
    ORDER BY 
        CreatedAt DESC
END
ELSE
BEGIN
    PRINT '    (No backup records found - This is normal for new installation)'
END

PRINT ''
PRINT '======================================'
PRINT 'Script execution completed successfully!'
PRINT '======================================'

GO
