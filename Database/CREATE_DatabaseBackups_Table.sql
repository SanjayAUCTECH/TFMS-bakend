-- =====================================================
-- Create DatabaseBackups Table
-- =====================================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DatabaseBackups')
BEGIN
    CREATE TABLE DatabaseBackups (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        BackupDate  DATETIME NOT NULL,
        BackupName  NVARCHAR(255) NOT NULL,
        Location    NVARCHAR(500) NOT NULL,
        Remarks     NVARCHAR(MAX) NULL,
        AddedBy     NVARCHAR(100) NULL,
        CreatedAt   DATETIME NOT NULL DEFAULT GETUTCDATE(),
        
        INDEX IX_DatabaseBackups_BackupDate (BackupDate DESC),
        INDEX IX_DatabaseBackups_CreatedAt (CreatedAt DESC)
    );
    
    PRINT 'DatabaseBackups table created successfully.';
END
ELSE
BEGIN
    PRINT 'DatabaseBackups table already exists.';
END
GO
