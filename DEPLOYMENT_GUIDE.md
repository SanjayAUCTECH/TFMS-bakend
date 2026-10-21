# TFMS Backend Deployment Guide

## 📦 Package Details
- **Package Name**: TFMS-Backend-Publish-20261018-192504.zip
- **Size**: 6.31 MB
- **Build Date**: October 18, 2026
- **Build Configuration**: Release
- **Target Framework**: .NET 8.0

## 🚀 Deployment Steps

### 1. Prerequisites
- **.NET 8.0 Runtime** installed on server
- **SQL Server** accessible with connection string
- **IIS** (for Windows Server) or **Kestrel** (for Linux)
- Port **9001** available (or configure different port)

### 2. Extract Files
```bash
# Extract ZIP file to deployment directory
# Example: C:\inetpub\TFMS-Backend\
```

### 3. Configure Settings

#### Update `appsettings.Production.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=YOUR_SERVER;Database=TFMS_SoftwareDB1;User Id=YOUR_USER;Password=YOUR_PASSWORD;Encrypt=False;TrustServerCertificate=True"
  },
  "CloudinarySettings": {
    "CloudName": "YOUR_CLOUD_NAME",
    "ApiKey": "YOUR_API_KEY",
    "ApiSecret": "YOUR_API_SECRET"
  },
  "JwtSettings": {
    "SecretKey": "YOUR_SECRET_KEY_MINIMUM_32_CHARACTERS",
    "Issuer": "TFMSApi",
    "Audience": "TFMSClient",
    "ExpiryInMinutes": 1440
  }
}
```

### 4. Database Setup

#### A. Run Database Migrations:
```sql
-- 1. AlertTimeMaster Setup
USE TFMS_SoftwareDB1;
GO
-- Run: Database/AlertTimeMaster_Setup.sql

-- 2. Fund Pool Monthly Balance Setup
-- Run: Database/FundPoolMonthlyBalance_Setup.sql
-- Or use the updated procedures:
-- - Database/Update_SaveFundPoolMonthlyBalance_WithArray.sql
-- - Database/Fix_GET_Procedures_IsDeleted.sql
-- - Database/Fix_DeleteFundPoolMonthlyBalance.sql

-- 3. Partner AltMobile Column
ALTER TABLE Partners ADD AltMobile NVARCHAR(20) NULL;
GO
-- Update sp_GetPartners, sp_CreatePartner, sp_UpdatePartner
```

#### B. Verify Table Types:
```sql
-- Check if FundPoolMonthlyBalanceTableType exists
SELECT * FROM sys.types WHERE name = 'FundPoolMonthlyBalanceTableType';
```

### 5. Run Application

#### Option A: Windows Service (Recommended)
```powershell
# Install as Windows Service
sc create "TFMS Backend" binPath="C:\inetpub\TFMS-Backend\TFMS_software_api.exe" start=auto
sc start "TFMS Backend"
```

#### Option B: IIS Hosting
1. Open IIS Manager
2. Create new Application Pool (.NET CLR Version: No Managed Code)
3. Create new Website/Application
4. Point to publish folder
5. Set Application Pool
6. Start website

#### Option C: Command Line (Development/Testing)
```bash
cd /path/to/publish
./TFMS_software_api.exe
# Or on Linux:
dotnet TFMS_software_api.dll
```

### 6. Verify Deployment
```bash
# Check if API is running
curl http://localhost:9001/api/health
# Or use browser
http://YOUR_SERVER_IP:9001/swagger
```

## 🔧 Configuration Options

### Change Port
Edit `appsettings.Production.json`:
```json
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:YOUR_PORT"
      }
    }
  }
}
```

### Enable HTTPS
```json
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://0.0.0.0:443",
        "Certificate": {
          "Path": "certificate.pfx",
          "Password": "YOUR_CERT_PASSWORD"
        }
      }
    }
  }
}
```

## 📋 New Features in This Release

### 1. Fund Pool Monthly Balance API
- **POST** `/api/FundPoolMonthlyBalance/save` - Save monthly balance snapshot
- **GET** `/api/FundPoolMonthlyBalance?reportMonth=X&reportYear=Y` - Get specific month
- **GET** `/api/FundPoolMonthlyBalance/all` - Get all reports with pagination
- **DELETE** `/api/FundPoolMonthlyBalance?reportMonth=X&reportYear=Y` - Soft delete

**Features:**
- Manual data entry via array
- Current Fund Pool + Buffer Fund Pool tracking
- Soft delete (IsDeleted = 1)
- GET APIs filter IsDeleted = 0
- Pagination support

### 2. Partner API Enhancement
- Added `AltMobile` field to Partner model
- Updated all CRUD operations
- Updated stored procedures

## 🔍 Troubleshooting

### Issue: API not starting
**Solution**: Check logs in Event Viewer or console output

### Issue: Database connection failed
**Solution**: 
- Verify connection string in appsettings.Production.json
- Ensure SQL Server allows remote connections
- Check firewall rules for SQL Server port (1433)

### Issue: 404 on API calls
**Solution**: 
- Verify ASPNETCORE_ENVIRONMENT is set to "Production"
- Check if port is accessible
- Review IIS bindings/application path

### Issue: Stored procedure not found
**Solution**: 
- Run all SQL migration scripts
- Verify procedure exists: `SELECT * FROM sys.procedures WHERE name LIKE '%FundPool%'`

## 📝 Environment Variables

```bash
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://0.0.0.0:9001
```

## 🔐 Security Checklist
- [ ] Update JWT SecretKey (minimum 32 characters)
- [ ] Change database password
- [ ] Update Cloudinary credentials
- [ ] Enable HTTPS in production
- [ ] Configure CORS for specific origins
- [ ] Review user permissions in database

## 📞 Support
For issues or questions, contact the development team.

## 📄 License
Internal use only - TFMS Software

---
**Build Information:**
- Compiler: .NET 8.0 SDK
- Build Warnings: 74 (non-critical)
- Total DLLs: 56 files
- Publish Size: 19.45 MB (compressed: 6.31 MB)
