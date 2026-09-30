# PowerShell Script to Extract sp_GetContractRoomInstallments Definition from Database
# This will fetch the actual procedure from database

$serverInstance = "160.25.62.124,1433"
$database = "TFMS_TestSoftwareDB"
$username = "tfms_user"
$password = "tfms@123"
$procedureName = "sp_GetContractRoomInstallments"

$connectionString = "Server=$serverInstance;Database=$database;User Id=$username;Password=$password;TrustServerCertificate=True;Encrypt=True;"

try {
    Add-Type -AssemblyName "System.Data"
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    Write-Host "Connected to database successfully!" -ForegroundColor Green
    Write-Host "Fetching procedure: $procedureName" -ForegroundColor Yellow
    Write-Host ""
    
    # Query to get procedure definition
    $query = @"
SELECT OBJECT_DEFINITION(OBJECT_ID('$procedureName')) AS ProcedureDefinition
"@
    
    $command = New-Object System.Data.SqlClient.SqlCommand($query, $connection)
    $reader = $command.ExecuteReader()
    
    if ($reader.Read()) {
        $definition = $reader["ProcedureDefinition"]
        
        if ($definition) {
            # Save to file
            $outputFile = Join-Path $PSScriptRoot "sp_GetContractRoomInstallments_CURRENT.sql"
            $definition | Out-File -FilePath $outputFile -Encoding UTF8
            
            Write-Host "Procedure definition saved to: $outputFile" -ForegroundColor Green
            Write-Host ""
            Write-Host "=== CURRENT PROCEDURE DEFINITION ===" -ForegroundColor Yellow
            Write-Host ""
            Write-Host $definition
        }
        else {
            Write-Host "Procedure '$procedureName' not found in database!" -ForegroundColor Red
        }
    }
    
    $reader.Close()
    $connection.Close()
    
    Write-Host ""
    Write-Host "Connection closed." -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
