# Create Backup Folder on SQL Server Machine

## Problem
The folder `C:\Backups\Database` does not exist on the remote SQL Server machine (`160.25.62.124`), and the SQL Server service account doesn't have permission to create it automatically.

## Solution Options

### Option 1: Manual Creation (RECOMMENDED - Quick & Easy)

**Steps:**
1. Login to SQL Server machine (`160.25.62.124`)
2. Open File Explorer
3. Navigate to `C:\` drive
4. Create folder: `Backups`
5. Inside `Backups`, create folder: `Database`
6. Final path: `C:\Backups\Database`

**Done!** After this, the backup feature will work perfectly.

---

### Option 2: PowerShell Script (Run on SQL Server Machine)

If you have PowerShell access to SQL Server machine:

```powershell
# Create the backup directory
New-Item -Path "C:\Backups\Database" -ItemType Directory -Force

# Grant Full Control to SQL Server Service Account
# Replace 'NT SERVICE\MSSQL$SQLEXPRESS' with your SQL Server service account
$acl = Get-Acl "C:\Backups\Database"
$permission = "NT SERVICE\MSSQL$SQLEXPRESS","FullControl","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.SetAccessRule($accessRule)
Set-Acl "C:\Backups\Database" $acl

Write-Host "Backup folder created successfully!" -ForegroundColor Green
```

---

### Option 3: Command Prompt (Run on SQL Server Machine)

```cmd
mkdir C:\Backups\Database
icacls "C:\Backups\Database" /grant "NT SERVICE\MSSQL$SQLEXPRESS:(OI)(CI)F" /T
echo Folder created successfully!
```

---

### Option 4: Using RDP/Remote Desktop

1. Connect to SQL Server machine via Remote Desktop
2. Press `Win + R`
3. Type: `cmd` and press Enter
4. Run: `mkdir C:\Backups\Database`
5. Done!

---

## Verify Folder Creation

After creating the folder, verify from your local machine:

```powershell
# Test if SQL Server can access the folder
sqlcmd -S "160.25.62.124,1433" -U "tfms_user" -P "tfms@123" -d "TFMS_TestSoftwareDB" -C -Q "BACKUP DATABASE TFMS_TestSoftwareDB TO DISK = 'C:\Backups\Database\test_backup.bak' WITH INIT"
```

If successful, you'll see: `Processed X pages for database 'TFMS_TestSoftwareDB'`

---

## Alternative: Use Existing SQL Server Backup Folder

If you cannot create `C:\Backups\Database`, you can use SQL Server's default backup location which already exists:

```
C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup
```

Change the location in the frontend form to this path when creating backups.

---

## Contact Server Administrator

If you don't have access to the SQL Server machine, please contact your server administrator and request:

> "Please create folder `C:\Backups\Database` on the SQL Server machine and grant write permissions to the SQL Server service account."

---

Created: October 30, 2026
Server: 160.25.62.124
Database: TFMS_TestSoftwareDB
