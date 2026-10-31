# 📊 Database Backup Feature - Schema Documentation

## 🎯 Overview

**Feature:** Database Backup Management  
**Database Objects:** 1 Table, 2 Indexes, 0 Stored Procedures  
**Dependencies:** None (Standalone feature)  

---

## 📁 Files Included

### Main Schema File
**File:** `DATABASE_BACKUP_FEATURE_COMPLETE_SCHEMA.sql`

**Purpose:** Creates all required database objects for the backup feature

**What it does:**
- ✅ Creates `DatabaseBackups` table
- ✅ Creates performance indexes
- ✅ Verifies table structure
- ✅ Tests CRUD operations
- ✅ Provides detailed summary

**Safe to run:** ✅ Yes - Multiple times, idempotent script

---

## 🗄️ Database Objects Created

### 1. Table: DatabaseBackups

```sql
CREATE TABLE [dbo].[DatabaseBackups]
(
    [Id]         INT            IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [BackupDate] DATETIME       NOT NULL,
    [BackupName] NVARCHAR(100)  NOT NULL,
    [Location]   NVARCHAR(500)  NOT NULL,
    [Remarks]    NVARCHAR(500)  NULL,
    [AddedBy]    NVARCHAR(100)  NULL,
    [CreatedAt]  DATETIME       NOT NULL DEFAULT GETUTCDATE()
)
```

**Column Details:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| Id | INT IDENTITY | No | Primary key, auto-increment |
| BackupDate | DATETIME | No | When backup was created (user selected) |
| BackupName | NVARCHAR(100) | No | Backup file name without extension |
| Location | NVARCHAR(500) | No | Server path where .bak file is stored |
| Remarks | NVARCHAR(500) | Yes | Optional notes about the backup |
| AddedBy | NVARCHAR(100) | Yes | Username who created the backup |
| CreatedAt | DATETIME | No | Record creation timestamp (UTC) |

**Example Data:**

```
Id: 1
BackupDate: 2026-10-31 11:45:30
BackupName: TFMS_Backup_20261031_114530
Location: C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup
Remarks: Monthly backup
AddedBy: admin
CreatedAt: 2026-10-31 11:45:35
```

### 2. Index: IX_DatabaseBackups_BackupDate

```sql
CREATE NONCLUSTERED INDEX [IX_DatabaseBackups_BackupDate]
ON [dbo].[DatabaseBackups] ([BackupDate] DESC)
```

**Purpose:** Optimizes queries that filter or sort by BackupDate

**Used by:**
- Backup listing page (default sort by date)
- Date range searches

### 3. Index: IX_DatabaseBackups_CreatedAt

```sql
CREATE NONCLUSTERED INDEX [IX_DatabaseBackups_CreatedAt]
ON [dbo].[DatabaseBackups] ([CreatedAt] DESC)
```

**Purpose:** Optimizes queries for recent backups

**Used by:**
- Dashboard widgets showing latest backups
- Activity logs

---

## 🚀 How to Deploy

### Method 1: Using SQL Server Management Studio (SSMS)

1. **Connect to your database server**
   ```
   Server: YOUR_SERVER_NAME
   Database: TFMS_TestSoftwareDB
   Authentication: SQL Server or Windows
   ```

2. **Open the schema file**
   ```
   File → Open → File
   Select: DATABASE_BACKUP_FEATURE_COMPLETE_SCHEMA.sql
   ```

3. **Execute the script**
   ```
   Press F5 or click Execute button
   ```

4. **Verify success**
   ```
   Look for: "✅ SUCCESS: All database objects created"
   ```

### Method 2: Using sqlcmd Command Line

```powershell
sqlcmd -S YOUR_SERVER -d TFMS_TestSoftwareDB -i "DATABASE_BACKUP_FEATURE_COMPLETE_SCHEMA.sql"
```

### Method 3: Automated Deployment

```powershell
# PowerShell script
$server = "YOUR_SERVER"
$database = "TFMS_TestSoftwareDB"
$scriptPath = "DATABASE_BACKUP_FEATURE_COMPLETE_SCHEMA.sql"

Invoke-Sqlcmd -ServerInstance $server -Database $database -InputFile $scriptPath
```

---

## ✅ Verification Steps

### 1. Check Table Exists

```sql
SELECT * FROM sys.tables WHERE name = 'DatabaseBackups'
```

**Expected:** 1 row returned

### 2. Verify Columns

```sql
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME = 'DatabaseBackups'
ORDER BY 
    ORDINAL_POSITION
```

**Expected:** 7 rows (Id, BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt)

### 3. Check Indexes

```sql
SELECT 
    name AS IndexName,
    type_desc AS IndexType
FROM 
    sys.indexes
WHERE 
    object_id = OBJECT_ID('DatabaseBackups')
    AND name IS NOT NULL
```

**Expected:** At least 2 indexes

### 4. Test Insert

```sql
INSERT INTO DatabaseBackups 
(BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt)
VALUES 
(GETDATE(), 'TEST_Backup', 'C:\Test', 'Test only', 'admin', GETUTCDATE())

-- Verify
SELECT * FROM DatabaseBackups WHERE BackupName = 'TEST_Backup'

-- Cleanup
DELETE FROM DatabaseBackups WHERE BackupName = 'TEST_Backup'
```

**Expected:** Insert, Select, and Delete all succeed

---

## 📊 Sample Queries

### View All Backups (Latest First)

```sql
SELECT 
    Id,
    BackupDate,
    BackupName,
    Location,
    AddedBy,
    CreatedAt
FROM 
    DatabaseBackups
ORDER BY 
    CreatedAt DESC
```

### Search by Backup Name

```sql
SELECT * 
FROM DatabaseBackups
WHERE BackupName LIKE '%20261031%'
```

### Get Backups by Date Range

```sql
SELECT * 
FROM DatabaseBackups
WHERE BackupDate BETWEEN '2026-10-01' AND '2026-10-31'
ORDER BY BackupDate DESC
```

### Count Backups per User

```sql
SELECT 
    AddedBy,
    COUNT(*) AS BackupCount
FROM 
    DatabaseBackups
GROUP BY 
    AddedBy
ORDER BY 
    BackupCount DESC
```

### Find Large Gap in Backups

```sql
SELECT 
    b1.BackupDate AS LastBackup,
    b2.BackupDate AS NextBackup,
    DATEDIFF(day, b1.BackupDate, b2.BackupDate) AS DaysBetween
FROM 
    DatabaseBackups b1
INNER JOIN 
    DatabaseBackups b2 ON b2.Id = (
        SELECT MIN(Id) 
        FROM DatabaseBackups 
        WHERE BackupDate > b1.BackupDate
    )
WHERE 
    DATEDIFF(day, b1.BackupDate, b2.BackupDate) > 7
ORDER BY 
    DaysBetween DESC
```

---

## 🔧 Maintenance

### Regular Cleanup (Optional)

```sql
-- Delete backups older than 90 days
DELETE FROM DatabaseBackups
WHERE BackupDate < DATEADD(day, -90, GETDATE())
```

### Rebuild Indexes (Monthly)

```sql
-- Rebuild all indexes on DatabaseBackups table
ALTER INDEX ALL ON DatabaseBackups REBUILD
```

### Update Statistics (Weekly)

```sql
-- Update statistics for better query performance
UPDATE STATISTICS DatabaseBackups
```

---

## 🚨 Troubleshooting

### Issue: Table already exists error

**Solution:** This is normal! The script is idempotent and will skip creation if table exists.

### Issue: Permission denied

**Solution:** 
```sql
-- Grant permissions to application user
GRANT SELECT, INSERT, UPDATE, DELETE ON DatabaseBackups TO [YourAppUser]
```

### Issue: Indexes not created

**Solution:** Check if indexes already exist (script will skip if they do)

### Issue: Cannot find table after creation

**Solution:** 
```sql
-- Refresh SSMS Object Explorer (F5)
-- Or check in correct database
USE TFMS_TestSoftwareDB
SELECT * FROM DatabaseBackups
```

---

## 📝 Migration from Old Schema (If Applicable)

If you have an older version of the DatabaseBackups table:

```sql
-- Check current column count
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'DatabaseBackups'

-- If less than 7, you may need to add missing columns:
-- (Script will NOT alter existing tables - manual intervention required)

-- Example: Add missing column
ALTER TABLE DatabaseBackups 
ADD Remarks NVARCHAR(500) NULL
```

---

## 📊 Storage Estimates

**Row size:** ~800 bytes (average)

**Expected growth:**

| Backup Frequency | Rows per Year | Storage per Year |
|------------------|---------------|------------------|
| Daily | 365 | ~300 KB |
| Weekly | 52 | ~42 KB |
| Monthly | 12 | ~10 KB |

**Note:** This is just the metadata table. Actual .bak files stored separately.

---

## 🔒 Security Considerations

1. **Table Permissions:**
   - Application needs: SELECT, INSERT, DELETE
   - Users should not have direct access
   - Access through API only

2. **File System Permissions:**
   - SQL Server service account needs write access to backup location
   - Application may need read access to download backups

3. **Sensitive Data:**
   - No sensitive data stored in this table
   - Backup files may contain sensitive data (secure the file location)

---

## 📚 Related Documentation

- **Deployment Guide:** `LIVE_DEPLOYMENT_CHECKLIST.md`
- **Quick Steps:** `QUICK_DEPLOYMENT_STEPS.md`
- **Migration Script:** `LIVE_DATABASE_BACKUP_FEATURE_MIGRATION.sql`
- **Complete Solution:** `FINAL_BACKUP_SOLUTION.md`

---

## ✅ Checklist

Before marking deployment as complete:

- [ ] Schema script executed successfully
- [ ] All 7 columns present in DatabaseBackups table
- [ ] At least 2 indexes created
- [ ] Test insert/delete operations successful
- [ ] Permissions granted to application user
- [ ] Backend application deployed
- [ ] Frontend application deployed
- [ ] End-to-end backup tested
- [ ] Download functionality tested

---

## 🎉 Success Criteria

Deployment successful when:

1. ✅ Script shows "✅ SUCCESS: All database objects created"
2. ✅ Table has 7 columns
3. ✅ Indexes verified
4. ✅ Test operations pass
5. ✅ Application can create backups
6. ✅ Application can retrieve backup list
7. ✅ Application can download backup files

---

**Status:** Production Ready  
**Version:** 1.0  
**Last Updated:** October 31, 2026  
