-- Enable xp_cmdshell on SQL Server
-- This is required to create backup directories automatically
-- Run this script as sysadmin/sa user on SQL Server

USE master;
GO

-- Enable show advanced options
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- Enable xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO

-- Verify configuration
EXEC sp_configure 'xp_cmdshell';
GO

-- Test folder creation
EXEC xp_cmdshell 'mkdir C:\Backups';
EXEC xp_cmdshell 'mkdir C:\Backups\Database';
GO

-- Verify folder exists
EXEC xp_cmdshell 'dir C:\Backups\Database';
GO

PRINT 'xp_cmdshell enabled successfully!';
PRINT 'Backup folder C:\Backups\Database created!';
GO
