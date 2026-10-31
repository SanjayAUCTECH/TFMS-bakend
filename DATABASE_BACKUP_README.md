# Database Backup System - Setup & Usage Guide

## ✅ Successfully Implemented!

### 📊 Database Table
**Table Name:** `DatabaseBackups`

**Columns:**
- `Id` (INT, Primary Key, Auto-increment)
- `BackupDate` (DATETIME, NOT NULL)
- `BackupName` (NVARCHAR(255), NOT NULL)
- `Location` (NVARCHAR(500), NOT NULL)
- `Remarks` (NVARCHAR(MAX), NULL)
- `AddedBy` (NVARCHAR(100), NULL)
- `CreatedAt` (DATETIME, NOT NULL, Default: GETUTCDATE())

**Indexes:**
- `IX_DatabaseBackups_BackupDate` (DESC)
- `IX_DatabaseBackups_CreatedAt` (DESC)

---

## 🔧 Default Backup Location

**SQL Server Backup Directory (Verified & Working):**
```
C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup
```

✅ This folder already exists on the remote SQL Server
✅ SQL Server service account has write permissions
✅ This is the official SQL Server backup directory

---

## 🎯 API Endpoints

### 1. Create Backup
**POST** `/api/DatabaseBackups`

**Request Body:**
```json
{
  "backupDate": "2026-10-30T12:00:00.000Z",
  "backupName": "TFMS_Backup_20261030_120000",
  "location": "C:\\Program Files\\Microsoft SQL Server\\MSSQL16.SQLEXPRESS\\MSSQL\\Backup",
  "remarks": "Monthly backup"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Database backup created successfully.",
  "data": {
    "id": 1,
    "backupDate": "2026-10-30T12:00:00",
    "backupName": "TFMS_Backup_20261030_120000",
    "location": "C:\\Program Files\\Microsoft SQL Server\\MSSQL16.SQLEXPRESS\\MSSQL\\Backup",
    "remarks": "Monthly backup",
    "addedBy": "admin",
    "createdAt": "2026-10-30T12:00:05"
  }
}
```

### 2. Get All Backups
**GET** `/api/DatabaseBackups?pageNumber=1&pageSize=10&search=TFMS`

### 3. Get Backup by ID
**GET** `/api/DatabaseBackups/{id}`

---

## 🖥️ Frontend Features

**Page:** Database Backup Management

**Auto-filled Fields:**
- ✅ Backup Date (Current date, disabled)
- ✅ Backup Name (Auto-generated: `TFMS_Backup_YYYYMMDD_HHmmss`, read-only)
- ✅ Backup Location (SQL Server default backup directory, editable)

**User Actions:**
- Change backup location if needed
- Add optional remarks
- Click "Create Backup"

---

## 📝 Important Notes

1. **Backup File Format:** `.bak` file with timestamp
   - Example: `TFMS_Backup_20261030_120000_20261030_120005.bak`

2. **Permissions:** SQL Server service account must have write access to the backup folder

3. **Backup Time:** May take several minutes for large databases

4. **Storage:** Ensure sufficient disk space on SQL Server machine

---

## 🚀 Quick Test

1. Open browser: `http://localhost:5173/`
2. Navigate to: **Database Backup** page
3. Click: **"Create Backup"**
4. Form auto-fills with:
   - Date: Today
   - Name: `TFMS_Backup_YYYYMMDD_HHmmss`
   - Location: SQL Server Backup Directory
5. Click: **"Create Backup"** button
6. ✅ Success! Backup created

---

## 🔍 Verify Backup

**Check in SQL Server:**
```sql
SELECT * FROM DatabaseBackups ORDER BY CreatedAt DESC;
```

**Check Physical File:**
Navigate to SQL Server machine:
```
C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup
```

---

## 💡 Alternative Backup Locations

If you want to use a different folder:

1. Create folder on SQL Server machine
2. Grant write permissions to SQL Server service account
3. Update location in frontend form
4. Create backup

**Example Alternative Paths:**
- `D:\DatabaseBackups`
- `E:\Backups`
- `\\NetworkShare\Backups\Database`

---

Created: October 30, 2026
Status: ✅ Production Ready
