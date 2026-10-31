# ⚡ Quick Deployment Steps - Database Backup Feature

## 🎯 For Database Admin

### Step 1: Backup Live Database (Safety First!)

```sql
BACKUP DATABASE [TFMS_TestSoftwareDB]
TO DISK = 'C:\Backups\PreMigration_Backup.bak'
WITH FORMAT, INIT;
```

### Step 2: Run Migration Script

1. Open: `LIVE_DATABASE_BACKUP_FEATURE_MIGRATION.sql`
2. Connect to live database
3. Execute (F5)
4. Wait for: **"✅ MIGRATION SUCCESSFUL!"**

### Step 3: Verify

```sql
-- Should show 7 columns
SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'DatabaseBackups'
ORDER BY ORDINAL_POSITION;
```

**Expected:** 7 rows (Id, BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt)

---

## 🎯 For Application Admin

### Step 1: Deploy Backend

```powershell
# Stop service
Stop-Service -Name "TFMS_API_Service"

# Copy new files
Copy-Item "source\*" "destination\" -Recurse -Force

# Start service
Start-Service -Name "TFMS_API_Service"
```

### Step 2: Deploy Frontend

```powershell
# Copy build files
Copy-Item "dist\*" "wwwroot\TFMS\" -Recurse -Force

# Clear old files first
Remove-Item "wwwroot\TFMS\*" -Recurse -Force
Copy-Item "dist\*" "wwwroot\TFMS\" -Recurse -Force
```

### Step 3: Test

1. Open application
2. Go to Database Backup page
3. Create backup → Should succeed
4. Download backup → File should download

---

## ✅ Quick Checklist

```
□ Database backed up
□ Migration script executed successfully
□ 7 columns verified
□ Backend deployed
□ Frontend deployed
□ Create backup test passed
□ Download backup test passed
```

---

## 🚨 If Something Goes Wrong

### Rollback Database (unlikely needed)

```sql
RESTORE DATABASE [TFMS_TestSoftwareDB]
FROM DISK = 'C:\Backups\PreMigration_Backup.bak'
WITH REPLACE;
```

### Rollback Application

```powershell
# Restore from backup folder
Copy-Item "backup\*" "production\" -Recurse -Force
Restart-Service -Name "TFMS_API_Service"
```

---

## 📊 Expected Results

### Migration Script Output

```
✓ DatabaseBackups table exists
✓ All required columns present
✓ Table structure verified
✓ Performance index created
✓ Insert/Delete operations working

✅ MIGRATION SUCCESSFUL!
```

### Application Test

```
✓ Page loads without errors
✓ Can create backup
✓ Can view backups in table
✓ Can download .bak file
✓ File appears in Downloads folder
```

---

## 📞 Need Help?

**Check these first:**
1. SQL script output messages
2. Backend API logs
3. Browser console (F12)

**Common Issues:**
- Table already exists → OK, safe to continue
- Column already exists → OK, safe to continue
- Permission denied → Run as admin / check SQL permissions

---

## 🎉 Done!

Once you see **"MIGRATION SUCCESSFUL"** and tests pass, you're all set! ✅
