# TFMS Backend Deployment Instructions

## 📦 Published Package Information

**File Name:** `TFMS_Backend_Published_20260923_194841.zip`  
**Size:** ~7.2 MB  
**Build Date:** September 23, 2026 - 19:48:50  
**Location:** `g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend\`

---

## 🔧 What's Fixed in This Release

### Issue Fixed:
**Dashboard API - CampOccupancy month filtering**

- **Problem:** The `campOccupancy` array was not respecting the `month` parameter in the API
- **File Changed:** `Repositories/DashboardRepository.cs`
- **Solution:** Updated query to use `ContractRoomInstallments` table with proper month filtering instead of `Rooms.Status` column

### API Endpoint Affected:
```
GET /api/Dashboard/stats?month=2026-07
```

### Expected Behavior After Deployment:
- `campOccupancy` will now show month-specific data (e.g., Jul26 data when `month=2026-07`)
- Occupied rooms calculated from `ContractRoomInstallments` table
- Vacant rooms = Total Rooms - Occupied

---

## 🚀 Deployment Steps

### Option 1: Windows Server (IIS)

1. **Stop IIS Application Pool**
   ```powershell
   Stop-WebAppPool -Name "YourAppPoolName"
   ```

2. **Backup Current Deployment**
   ```powershell
   Copy-Item "C:\inetpub\wwwroot\TFMS_API" -Destination "C:\inetpub\wwwroot\TFMS_API_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Recurse
   ```

3. **Extract ZIP to Deployment Directory**
   ```powershell
   Expand-Archive -Path "TFMS_Backend_Published_20260923_194841.zip" -DestinationPath "C:\inetpub\wwwroot\TFMS_API" -Force
   ```

4. **Verify appsettings.Production.json**
   - Ensure database connection string is correct
   - Check JWT settings
   - Verify CORS allowed origins

5. **Start IIS Application Pool**
   ```powershell
   Start-WebAppPool -Name "YourAppPoolName"
   ```

6. **Test API**
   ```
   https://tfmstestapi.auctech.ae/api/Dashboard/stats?month=2026-07
   ```

---

### Option 2: Linux Server (Ubuntu/Debian)

1. **Stop Existing Service**
   ```bash
   sudo systemctl stop tfms-api.service
   ```

2. **Backup Current Deployment**
   ```bash
   sudo cp -r /var/www/tfms-api /var/www/tfms-api-backup-$(date +%Y%m%d_%H%M%S)
   ```

3. **Upload ZIP File**
   ```bash
   scp TFMS_Backend_Published_20260923_194841.zip user@server:/tmp/
   ```

4. **Extract on Server**
   ```bash
   sudo unzip -o /tmp/TFMS_Backend_Published_20260923_194841.zip -d /var/www/tfms-api/
   ```

5. **Set Permissions**
   ```bash
   sudo chown -R www-data:www-data /var/www/tfms-api/
   sudo chmod -R 755 /var/www/tfms-api/
   ```

6. **Verify Configuration**
   ```bash
   sudo nano /var/www/tfms-api/appsettings.Production.json
   ```

7. **Start Service**
   ```bash
   sudo systemctl start tfms-api.service
   sudo systemctl status tfms-api.service
   ```

8. **Check Logs**
   ```bash
   sudo journalctl -u tfms-api.service -f
   ```

9. **Test API**
   ```bash
   curl https://tfmstestapi.auctech.ae/api/Dashboard/stats?month=2026-07
   ```

---

### Option 3: Docker Container

1. **Stop and Remove Old Container**
   ```bash
   docker stop tfms-api
   docker rm tfms-api
   ```

2. **Extract Files**
   ```bash
   mkdir -p /opt/tfms-api
   unzip TFMS_Backend_Published_20260923_194841.zip -d /opt/tfms-api/
   ```

3. **Update appsettings.Production.json**

4. **Run New Container**
   ```bash
   docker run -d \
     --name tfms-api \
     -p 9001:8080 \
     -v /opt/tfms-api:/app \
     -e ASPNETCORE_ENVIRONMENT=Production \
     mcr.microsoft.com/dotnet/aspnet:8.0 \
     dotnet /app/TFMS_software_api.dll
   ```

5. **Check Logs**
   ```bash
   docker logs -f tfms-api
   ```

6. **Test API**
   ```bash
   curl http://localhost:9001/api/Dashboard/stats?month=2026-07
   ```

---

## ✅ Post-Deployment Verification

### 1. Health Check
```bash
curl https://tfmstestapi.auctech.ae/api/Dashboard/stats
```

Expected: Status 200 OK

### 2. Test Jul 2026 Data
```bash
curl "https://tfmstestapi.auctech.ae/api/Dashboard/stats?month=2026-07"
```

**Expected `campOccupancy` Response:**
```json
{
  "campOccupancy": [
    { "campName": "AMASCO.R1", "totalRooms": 37, "occupied": 36, "vacant": 1 },
    { "campName": "ASRE.R1", "totalRooms": 70, "occupied": 70, "vacant": 0 },
    { "campName": "BINSANAD.R1", "totalRooms": 164, "occupied": 164, "vacant": 0 },
    { "campName": "DARVISH", "totalRooms": 35, "occupied": 35, "vacant": 0 },
    { "campName": "HELIX", "totalRooms": 81, "occupied": 79, "vacant": 2 },
    { "campName": "HURAIZ", "totalRooms": 43, "occupied": 38, "vacant": 5 },
    { "campName": "JUBILEE.R2", "totalRooms": 38, "occupied": 36, "vacant": 2 },
    { "campName": "MUMTAZ.R2", "totalRooms": 25, "occupied": 22, "vacant": 3 }
  ]
}
```

### 3. Test Other Months
```bash
curl "https://tfmstestapi.auctech.ae/api/Dashboard/stats?month=2026-08"
curl "https://tfmstestapi.auctech.ae/api/Dashboard/stats?month=2026-09"
```

### 4. Test Without Month Parameter
```bash
curl "https://tfmstestapi.auctech.ae/api/Dashboard/stats"
```

Should show current month data.

---

## 📋 Important Files in Package

```
TFMS_software_api.dll          # Main application
appsettings.json               # Default configuration
appsettings.Production.json    # Production configuration (UPDATE THIS!)
web.config                     # IIS configuration
runtimes/                      # Platform-specific dependencies
wwwroot/                       # Static files (if any)
```

---

## ⚙️ Configuration Requirements

### Database Connection String
Update in `appsettings.Production.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=YOUR_SERVER;Database=TFMS_TestSoftwareDB;User Id=tfms_user;Password=YOUR_PASSWORD;TrustServerCertificate=True;Encrypt=True;"
  }
}
```

### JWT Configuration
```json
{
  "Jwt": {
    "Key": "YOUR_SECRET_KEY",
    "Issuer": "TFMS_API",
    "Audience": "TFMS_Client",
    "ExpiryHours": 8
  }
}
```

### CORS Origins
```json
{
  "AllowedOrigins": [
    "https://cefms.auctech.ae",
    "https://tfmstestapi.auctech.ae"
  ]
}
```

---

## 🔧 Troubleshooting

### Issue: API Returns 500 Error
**Solution:** Check database connection string and ensure SQL Server is accessible

### Issue: CORS Error in Browser
**Solution:** Verify `AllowedOrigins` in appsettings.Production.json includes your frontend URL

### Issue: Month Parameter Not Working
**Solution:** Ensure this deployment package is used (contains the fix)

### Issue: Permissions Error (Linux)
**Solution:** 
```bash
sudo chown -R www-data:www-data /var/www/tfms-api/
sudo chmod +x /var/www/tfms-api/TFMS_software_api
```

---

## 📞 Support

For any deployment issues, contact the development team with:
- Deployment option used (IIS/Linux/Docker)
- Error messages from logs
- Server environment details

---

## 📝 Changelog

### Version: 2026-09-23 (Build 194841)
- ✅ Fixed: Dashboard API `campOccupancy` now respects month parameter
- ✅ Updated: `DashboardRepository.cs` to use `ContractRoomInstallments` table
- ✅ Improved: Month-wise occupancy calculation logic

---

**Generated on:** September 23, 2026 @ 19:48:41  
**Build Environment:** Release (net8.0)  
**Target Platform:** Any CPU
