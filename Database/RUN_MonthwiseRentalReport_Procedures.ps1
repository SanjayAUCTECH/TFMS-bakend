# =============================================
# PowerShell Script: Create Month-wise Rental Report Procedures
# Description: Creates stored procedures for month-wise rental reporting
# Usage: Run this script to create/update the procedures
# =============================================

# Configuration
$ServerInstance = "160.25.62.124,1433"  # Remote SQL Server
$Database = "TFMS_SoftwareDB"            # Database name
$Username = "tfms_user"                  # SQL Server username
$Password = "tfms@123"                   # SQL Server password
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# SQL Files to execute
$SqlFiles = @(
    "sp_GetMonthwiseRentalReport.sql",
    "sp_GetMonthwiseRentalSummary.sql"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Creating Month-wise Rental Report Procedures" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: $ServerInstance" -ForegroundColor Yellow
Write-Host "Database: $Database" -ForegroundColor Yellow
Write-Host ""

# Check if SqlServer module is available
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "SqlServer module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}

Import-Module SqlServer

# Execute each SQL file
foreach ($SqlFile in $SqlFiles) {
    $FilePath = Join-Path -Path $ScriptPath -ChildPath $SqlFile
    
    if (Test-Path $FilePath) {
        Write-Host "Executing: $SqlFile" -ForegroundColor Green
        try {
            Invoke-Sqlcmd -ServerInstance $ServerInstance `
                         -Database $Database `
                         -Username $Username `
                         -Password $Password `
                         -InputFile $FilePath `
                         -ErrorAction Stop `
                         -Verbose
            
            Write-Host "Success: $SqlFile executed successfully!" -ForegroundColor Green
            Write-Host ""
        }
        catch {
            Write-Host "Error executing $SqlFile" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host ""
        }
    }
    else {
        Write-Host "File not found: $SqlFile" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Procedure creation completed!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "API Endpoints available:" -ForegroundColor Yellow
Write-Host "  GET  /api/monthwiserentalreport" -ForegroundColor White
Write-Host "  GET  /api/monthwiserentalreport/summary" -ForegroundColor White
Write-Host "  GET  /api/monthwiserentalreport/export" -ForegroundColor White
Write-Host ""
Write-Host "Backend starting on http://192.168.1.34:9001" -ForegroundColor Yellow
Write-Host ""
