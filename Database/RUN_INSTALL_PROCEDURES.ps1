# =============================================
# PowerShell Script to Execute Stored Procedure Installation
# This script will automatically install procedures to your database
# =============================================

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Database Procedure Installation Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Database Connection Details (from appsettings.Production.json)
$ServerInstance = "160.25.62.124,1433"
$Database = "TFMS_TestSoftwareDB"
$Username = "tfms_user"
$Password = "tfms@123"

# SQL File Path
$SqlFilePath = Join-Path $PSScriptRoot "INSTALL_ALL_PROCEDURES.sql"

Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  Server: $ServerInstance" -ForegroundColor White
Write-Host "  Database: $Database" -ForegroundColor White
Write-Host "  User: $Username" -ForegroundColor White
Write-Host ""

# Check if SQL file exists
if (-Not (Test-Path $SqlFilePath)) {
    Write-Host "ERROR: SQL file not found at: $SqlFilePath" -ForegroundColor Red
    exit 1
}

Write-Host "SQL File Found: $SqlFilePath" -ForegroundColor Green
Write-Host ""

# Read SQL file content
$SqlContent = Get-Content $SqlFilePath -Raw

# Replace "USE YourDatabaseName" with actual database name
$SqlContent = $SqlContent -replace "USE YourDatabaseName;", "USE [$Database];"

Write-Host "Connecting to database..." -ForegroundColor Yellow

try {
    # Create connection string
    $ConnectionString = "Server=$ServerInstance;Database=$Database;User Id=$Username;Password=$Password;TrustServerCertificate=True;Encrypt=True;Connection Timeout=30;"
    
    # Create SQL connection
    $Connection = New-Object System.Data.SqlClient.SqlConnection
    $Connection.ConnectionString = $ConnectionString
    $Connection.Open()
    
    Write-Host "Connected successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Executing SQL script..." -ForegroundColor Yellow
    Write-Host ""
    
    # Split SQL by GO statements
    $SqlBatches = $SqlContent -split "\r?\nGO\r?\n"
    
    $BatchNumber = 0
    foreach ($Batch in $SqlBatches) {
        $Batch = $Batch.Trim()
        if ($Batch -ne "") {
            $BatchNumber++
            
            try {
                $Command = $Connection.CreateCommand()
                $Command.CommandText = $Batch
                $Command.CommandTimeout = 120
                
                # Execute and capture messages
                $Reader = $Command.ExecuteReader()
                
                # Read all result sets
                do {
                    while ($Reader.Read()) {
                        for ($i = 0; $i -lt $Reader.FieldCount; $i++) {
                            Write-Host $Reader.GetValue($i) -ForegroundColor White
                        }
                    }
                } while ($Reader.NextResult())
                
                $Reader.Close()
                
            } catch {
                Write-Host "Batch $BatchNumber Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "SQL Script Execution Completed!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Restart your backend API" -ForegroundColor White
    Write-Host "  2. Test the endpoint at: http://192.168.1.34:9001/api/MonthwiseRentalReport?campId=1" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
} finally {
    if ($Connection.State -eq 'Open') {
        $Connection.Close()
        Write-Host "Database connection closed." -ForegroundColor Gray
    }
}

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
