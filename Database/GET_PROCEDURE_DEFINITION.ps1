# PowerShell Script to Extract Stored Procedure Definition
# Run this script to get sp_GetDashboardStats definition

$serverInstance = "160.25.62.124,1433"
$database = "TFMS_TestSoftwareDB"
$username = "tfms_user"
$password = "tfms@123"
$procedureName = "sp_GetDashboardStats"

$connectionString = "Server=$serverInstance;Database=$database;User Id=$username;Password=$password;TrustServerCertificate=True;Encrypt=True;"

try {
    # Load SQL Server assembly
    Add-Type -AssemblyName "System.Data"
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    Write-Host "Connected to database successfully!" -ForegroundColor Green
    
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
            $outputFile = Join-Path $PSScriptRoot "sp_GetDashboardStats_EXTRACTED.sql"
            $definition | Out-File -FilePath $outputFile -Encoding UTF8
            
            Write-Host "`nProcedure definition saved to: $outputFile" -ForegroundColor Green
            Write-Host "`n=== PROCEDURE DEFINITION ===`n" -ForegroundColor Yellow
            Write-Host $definition
        }
        else {
            Write-Host "Procedure '$procedureName' not found!" -ForegroundColor Red
        }
    }
    
    $reader.Close()
    $connection.Close()
    
    Write-Host "`nConnection closed." -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
