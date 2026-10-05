-- ═══════════════════════════════════════════════════════════════════
-- Fix Missing Columns in Incomes and Expenses Tables
-- ═══════════════════════════════════════════════════════════════════

PRINT 'Adding missing columns to Incomes and Expenses tables...';
GO

-- ─────────────────────────────────────────────────────────────────
-- Add missing columns to Incomes table
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Incomes') AND name = 'Nature')
BEGIN
    ALTER TABLE dbo.Incomes ADD Nature NVARCHAR(50) NULL;
    PRINT '✓ Nature column added to Incomes table';
END
ELSE
    PRINT '• Nature column already exists in Incomes table';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Incomes') AND name = 'RecipientRole')
BEGIN
    ALTER TABLE dbo.Incomes ADD RecipientRole NVARCHAR(100) NULL;
    PRINT '✓ RecipientRole column added to Incomes table';
END
ELSE
    PRINT '• RecipientRole column already exists in Incomes table';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Incomes') AND name = 'RecipientId')
BEGIN
    ALTER TABLE dbo.Incomes ADD RecipientId INT NULL;
    PRINT '✓ RecipientId column added to Incomes table';
END
ELSE
    PRINT '• RecipientId column already exists in Incomes table';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Incomes') AND name = 'RecipientName')
BEGIN
    ALTER TABLE dbo.Incomes ADD RecipientName NVARCHAR(200) NULL;
    PRINT '✓ RecipientName column added to Incomes table';
END
ELSE
    PRINT '• RecipientName column already exists in Incomes table';

GO

-- ─────────────────────────────────────────────────────────────────
-- Add missing columns to Expenses table
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Expenses') AND name = 'Nature')
BEGIN
    ALTER TABLE dbo.Expenses ADD Nature NVARCHAR(50) NULL;
    PRINT '✓ Nature column added to Expenses table';
END
ELSE
    PRINT '• Nature column already exists in Expenses table';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Expenses') AND name = 'RecipientRole')
BEGIN
    ALTER TABLE dbo.Expenses ADD RecipientRole NVARCHAR(100) NULL;
    PRINT '✓ RecipientRole column added to Expenses table';
END
ELSE
    PRINT '• RecipientRole column already exists in Expenses table';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Expenses') AND name = 'RecipientId')
BEGIN
    ALTER TABLE dbo.Expenses ADD RecipientId INT NULL;
    PRINT '✓ RecipientId column added to Expenses table';
END
ELSE
    PRINT '• RecipientId column already exists in Expenses table';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Expenses') AND name = 'RecipientName')
BEGIN
    ALTER TABLE dbo.Expenses ADD RecipientName NVARCHAR(200) NULL;
    PRINT '✓ RecipientName column added to Expenses table';
END
ELSE
    PRINT '• RecipientName column already exists in Expenses table';

GO

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'Incomes/Expenses Tables Fix Completed Successfully!';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
