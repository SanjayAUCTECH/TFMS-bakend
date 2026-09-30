# PowerShell Script to Update sp_GetTxnRecords Directly

$serverInstance = "160.25.62.124,1433"
$database = "TFMS_TestSoftwareDB"
$username = "tfms_user"
$password = "tfms@123"

$connectionString = "Server=$serverInstance;Database=$database;User Id=$username;Password=$password;TrustServerCertificate=True;Encrypt=True;"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Updating sp_GetTxnRecords" -ForegroundColor Cyan
Write-Host "Adding ContractRoomsTrns JOIN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    Add-Type -AssemblyName "System.Data"
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    Write-Host "✓ Connected to database: $database" -ForegroundColor Green
    Write-Host ""
    
    # Read SQL file
    $sqlFile = Join-Path $PSScriptRoot "EXECUTE_UPDATE_TxnRecords.sql"
    
    if (-not (Test-Path $sqlFile)) {
        throw "SQL file not found: $sqlFile"
    }
    
    # Read and parse SQL content
    $sqlContent = Get-Content $sqlFile -Raw
    
    # Extract ALTER PROCEDURE section
    $pattern = '(?s)ALTER PROCEDURE.*?END'
    if ($sqlContent -match $pattern) {
        $updateQuery = $matches[0]
    }
    else {
        throw "Could not find ALTER PROCEDURE statement in SQL file"
    }
    
    Write-Host "Executing ALTER PROCEDURE..." -ForegroundColor Yellow
    
    $command = New-Object System.Data.SqlClient.SqlCommand($updateQuery, $connection)
    $command.CommandTimeout = 60
    $command.ExecuteNonQuery() | Out-Null
    
    Write-Host ""
    Write-Host "✓ Procedure updated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Changes applied:" -ForegroundColor Cyan
    Write-Host "  - Added LEFT JOIN with ContractRoomsTrns table" -ForegroundColor White
    Write-Host "  - JOIN on ContractId AND TxnDate (date match)" -ForegroundColor White
    Write-Host "  - Added PaymentStatus column" -ForegroundColor White
    Write-Host "  - Added Month column" -ForegroundColor White
    Write-Host ""
    
    $connection.Close()
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Update completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "New API response will include:" -ForegroundColor Yellow
    Write-Host "  paymentStatus: from ContractRoomsTrns" -ForegroundColor White
    Write-Host "  month: from ContractRoomsTrns" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "✗ Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}
