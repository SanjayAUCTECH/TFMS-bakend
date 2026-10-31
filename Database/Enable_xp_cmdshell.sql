-- Enable xp_cmdshell for file operations
-- Run this script if backup download is not working

-- Show current configuration
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Enable xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

-- Verify configuration
EXEC sp_configure 'xp_cmdshell';
GO

-- Test xp_cmdshell
EXEC master.dbo.xp_cmdshell 'echo xp_cmdshell is working!';
GO
