# PowerShell Script to Execute Procedure Update Directly
# This will update sp_GetContractRoomInstallments in database

$serverInstance = "160.25.62.124,1433"
$database = "TFMS_TestSoftwareDB"
$username = "tfms_user"
$password = "tfms@123"

$connectionString = "Server=$serverInstance;Database=$database;User Id=$username;Password=$password;TrustServerCertificate=True;Encrypt=True;"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Updating sp_GetContractRoomInstallments" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    Add-Type -AssemblyName "System.Data"
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    Write-Host "✓ Connected to database: $database" -ForegroundColor Green
    Write-Host ""
    
    # Read SQL file
    $sqlFile = Join-Path $PSScriptRoot "EXECUTE_UPDATE_ContractRoomInstallments.sql"
    
    if (-not (Test-Path $sqlFile)) {
        throw "SQL file not found: $sqlFile"
    }
    
    # Read and parse SQL content
    $sqlContent = Get-Content $sqlFile -Raw
    
    # Extract ALTER PROCEDURE section (between ALTER and GO)
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
    Write-Host "  - Added LEFT JOIN with Camps table (CampName)" -ForegroundColor White
    Write-Host "  - Added LEFT JOIN with Rooms table (RoomNo)" -ForegroundColor White
    Write-Host "  - Explicit column selection (no more cri.*)" -ForegroundColor White
    Write-Host "  - @ContractId remains optional" -ForegroundColor White
    Write-Host ""
    
    # Verify the update
    Write-Host "Verifying parameters..." -ForegroundColor Yellow
    $verifyQuery = @"
SELECT 
    p.name AS ParameterName,
    TYPE_NAME(p.user_type_id) AS DataType,
    p.max_length AS MaxLength,
    CASE WHEN p.default_value IS NULL THEN 'NULL (Optional)' 
         ELSE CAST(p.default_value AS NVARCHAR(50)) 
    END AS DefaultValue
FROM sys.parameters p
WHERE p.object_id = OBJECT_ID('sp_GetContractRoomInstallments')
ORDER BY p.parameter_id
"@
    
    $verifyCmd = New-Object System.Data.SqlClient.SqlCommand($verifyQuery, $connection)
    $reader = $verifyCmd.ExecuteReader()
    
    Write-Host ""
    Write-Host "Current Procedure Parameters:" -ForegroundColor Cyan
    Write-Host "----------------------------" -ForegroundColor Cyan
    
    while ($reader.Read()) {
        $paramName = $reader["ParameterName"]
        $dataType = $reader["DataType"]
        $defaultVal = $reader["DefaultValue"]
        Write-Host "  $paramName - $dataType - Default: $defaultVal" -ForegroundColor White
    }
    
    $reader.Close()
    $connection.Close()
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Update completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now test the API endpoints:" -ForegroundColor Yellow
    Write-Host "  GET /api/ContractRoomInstallments/CNT-001" -ForegroundColor White
    Write-Host "  GET /api/ContractRoomInstallments?campId=1" -ForegroundColor White
    Write-Host "  GET /api/ContractRoomInstallments?status=Pending" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "✗ Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}
