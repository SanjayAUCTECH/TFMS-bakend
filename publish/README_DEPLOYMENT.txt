==============================================================================
TFMS Backend API - Deployment Instructions
Published: October 5, 2026
==============================================================================

📦 PACKAGE CONTENTS
------------------
This ZIP contains the published .NET 8.0 backend API with all dependencies.

Files included:
- TFMS_software_api.dll (Main application)
- All required DLL dependencies
- appsettings.json (Configuration file)
- web.config (IIS configuration)
- wwwroot/ (Static files)


🖥️ SERVER REQUIREMENTS
----------------------
- Windows Server 2016+ or Linux
- .NET 8.0 Runtime (ASP.NET Core Runtime)
  Download: https://dotnet.microsoft.com/download/dotnet/8.0
- SQL Server 2016+ (for database)
- IIS 10+ (for Windows) or Nginx/Apache (for Linux)


📝 DEPLOYMENT STEPS
-------------------

OPTION 1: IIS Deployment (Windows)
-----------------------------------
1. Install .NET 8.0 Hosting Bundle:
   https://dotnet.microsoft.com/download/dotnet/8.0

2. Extract ZIP contents to: C:\inetpub\wwwroot\tfms-api

3. Open IIS Manager:
   - Create new Application Pool:
     * Name: TFMS_API_Pool
     * .NET CLR version: No Managed Code
     * Managed pipeline mode: Integrated

   - Create new Website/Application:
     * Site name: TFMS_API
     * Physical path: C:\inetpub\wwwroot\tfms-api
     * Application pool: TFMS_API_Pool
     * Binding: http, port 9001 (or your preferred port)

4. Update appsettings.json with your database connection string

5. Grant permissions:
   - Give IIS_IUSRS read/execute permissions to the folder

6. Start the website in IIS


OPTION 2: Standalone (Kestrel) - Windows/Linux
-----------------------------------------------
1. Extract ZIP to any folder (e.g., /var/www/tfms-api)

2. Update appsettings.json with your connection string

3. Run the application:
   
   Windows:
   > cd "C:\path\to\tfms-api"
   > dotnet TFMS_software_api.dll --urls "http://0.0.0.0:9001"
   
   Linux:
   $ cd /var/www/tfms-api
   $ dotnet TFMS_software_api.dll --urls "http://0.0.0.0:9001"

4. (Optional) Create a Windows Service or systemd service:
   
   Linux systemd example:
   $ sudo nano /etc/systemd/system/tfms-api.service
   
   [Unit]
   Description=TFMS Backend API
   
   [Service]
   WorkingDirectory=/var/www/tfms-api
   ExecStart=/usr/bin/dotnet /var/www/tfms-api/TFMS_software_api.dll
   Restart=always
   RestartSec=10
   KillSignal=SIGINT
   SyslogIdentifier=tfms-api
   User=www-data
   Environment=ASPNETCORE_ENVIRONMENT=Production
   
   [Install]
   WantedBy=multi-user.target
   
   $ sudo systemctl enable tfms-api
   $ sudo systemctl start tfms-api


⚙️ CONFIGURATION
----------------

1. Edit appsettings.json:

{
  "ConnectionStrings": {
    "DefaultConnection": "Server=YOUR_SERVER;Database=TFMS_TestSoftwareDB;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True;Encrypt=True;"
  },
  "Jwt": {
    "Key": "YOUR_JWT_SECRET_KEY_MIN_32_CHARS",
    "Issuer": "TFMS_API",
    "Audience": "TFMS_Client",
    "ExpiryHours": 8
  },
  "AllowedOrigins": [
    "http://localhost:3000",
    "https://your-production-domain.com"
  ],
  "Cloudinary": {
    "CloudName": "YOUR_CLOUDINARY_NAME",
    "ApiKey": "YOUR_CLOUDINARY_KEY",
    "ApiSecret": "YOUR_CLOUDINARY_SECRET"
  }
}

2. Update environment:
   - Development: Uses appsettings.Development.json (included)
   - Production: Uses appsettings.Production.json (included)


🗄️ DATABASE SETUP
-----------------

1. Run all SQL scripts from Database/ folder (in order):
   - Fix_Missing_Sequences.sql
   - Fix_Incomes_Expenses_Columns.sql
   - AccountMaster_PaymentDate_Migration.sql
   - sp_GetAccountMasters.sql

2. Ensure database user has permissions:
   - db_datareader
   - db_datawriter
   - EXECUTE on stored procedures


🔍 VERIFICATION
---------------

1. After deployment, test the API:
   https://your-server:9001/swagger

2. Check health endpoint:
   https://your-server:9001/api/health

3. Test login:
   POST https://your-server:9001/api/Auth/login
   Body: { "username": "admin", "password": "your_password" }


📊 API ENDPOINTS
----------------
- Swagger UI: /swagger
- Authentication: /api/Auth
- Account Masters: /api/AccountMasters
- Vouchers: /api/Vouchers
- Payments: /api/Payments
- Reports: /api/Reports
[... and 60+ more endpoints]


🆕 LATEST CHANGES (Oct 5, 2026)
-------------------------------
✅ PaymentDate field added to AccountMasters
✅ GET /api/AccountMasters now uses sp_GetAccountMasters stored procedure
✅ PaymentDate filter with COALESCE logic (uses TransDate if NULL)
✅ UploadVoucher bulk upload supports Transaction Date and Payment Date
✅ All CRUD operations for AccountMasters use stored procedures


🐛 TROUBLESHOOTING
------------------

Issue: 500 Internal Server Error
Solution: Check logs in the 'logs' folder, verify database connection

Issue: Cannot connect to SQL Server
Solution: Ensure SQL Server allows remote connections, check firewall

Issue: Application doesn't start
Solution: Verify .NET 8.0 Runtime is installed, check permissions

Issue: CORS errors
Solution: Add your frontend URL to AllowedOrigins in appsettings.json


📞 SUPPORT
----------
For issues or questions, contact the development team.


==============================================================================
© 2026 TFMS Software - All Rights Reserved
==============================================================================
