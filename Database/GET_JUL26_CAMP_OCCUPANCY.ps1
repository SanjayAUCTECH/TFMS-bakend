# PowerShell Script to Get Jul 2026 Camp Occupancy Data
# This will show exact data for July 2026

$serverInstance = "160.25.62.124,1433"
$database = "TFMS_TestSoftwareDB"
$username = "tfms_user"
$password = "tfms@123"

$connectionString = "Server=$serverInstance;Database=$database;User Id=$username;Password=$password;TrustServerCertificate=True;Encrypt=True;"

try {
    Add-Type -AssemblyName "System.Data"
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    Write-Host "================================" -ForegroundColor Green
    Write-Host "Jul 2026 Camp Occupancy Report" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    Write-Host ""
    
    # Query to get Jul26 camp occupancy
    $query = @"
SELECT
    ca.Name AS CampName,
    COUNT(r.Id) AS TotalRooms,
    ISNULL(
    (
        SELECT COUNT(DISTINCT cri0.RoomNo)
        FROM ContractRoomInstallments cri0
        WHERE ISNULL(cri0.IsDeleted, 0) = 0
          AND cri0.CampId = ca.Id
          AND cri0.RoomNo IS NOT NULL
          AND cri0.Month = 'Jul26'
    ), 0) AS Occupied,
    COUNT(r.Id) - ISNULL(
    (
        SELECT COUNT(DISTINCT cri0.RoomNo)
        FROM ContractRoomInstallments cri0
        WHERE ISNULL(cri0.IsDeleted, 0) = 0
          AND cri0.CampId = ca.Id
          AND cri0.RoomNo IS NOT NULL
          AND cri0.Month = 'Jul26'
    ), 0) AS Vacant
FROM Camps ca
LEFT JOIN Rooms r
    ON r.CampId = ca.Id
   AND r.IsDeleted = 0
WHERE ca.Status = 'Active'
  AND ca.IsDeleted = 0
GROUP BY ca.Id, ca.Name
ORDER BY ca.Name
"@
    
    $command = New-Object System.Data.SqlClient.SqlCommand($query, $connection)
    $reader = $command.ExecuteReader()
    
    $results = @()
    while ($reader.Read()) {
        $campName = $reader["CampName"]
        $totalRooms = $reader["TotalRooms"]
        $occupied = $reader["Occupied"]
        $vacant = $reader["Vacant"]
        
        $results += [PSCustomObject]@{
            CampName = $campName
            TotalRooms = $totalRooms
            Occupied = $occupied
            Vacant = $vacant
            OccupancyPct = if ($totalRooms -gt 0) { [math]::Round(($occupied / $totalRooms) * 100, 1) } else { 0 }
        }
        
        Write-Host "Camp: $campName" -ForegroundColor Yellow
        Write-Host "  Total Rooms: $totalRooms" -ForegroundColor White
        Write-Host "  Occupied: $occupied" -ForegroundColor Green
        Write-Host "  Vacant: $vacant" -ForegroundColor Red
        if ($totalRooms -gt 0) {
            $pct = [math]::Round(($occupied / $totalRooms) * 100, 1)
            Write-Host "  Occupancy: $pct%" -ForegroundColor Cyan
        }
        Write-Host ""
    }
    
    $reader.Close()
    
    # Summary
    $totalCamps = $results.Count
    $totalAllRooms = ($results | Measure-Object -Property TotalRooms -Sum).Sum
    $totalOccupied = ($results | Measure-Object -Property Occupied -Sum).Sum
    $totalVacant = ($results | Measure-Object -Property Vacant -Sum).Sum
    
    Write-Host "================================" -ForegroundColor Green
    Write-Host "Overall Summary" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    Write-Host "Total Camps: $totalCamps" -ForegroundColor White
    Write-Host "Total Rooms: $totalAllRooms" -ForegroundColor White
    Write-Host "Total Occupied: $totalOccupied" -ForegroundColor Green
    Write-Host "Total Vacant: $totalVacant" -ForegroundColor Red
    if ($totalAllRooms -gt 0) {
        $overallPct = [math]::Round(($totalOccupied / $totalAllRooms) * 100, 1)
        Write-Host "Overall Occupancy: $overallPct%" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Save to CSV
    $outputFile = Join-Path $PSScriptRoot "Jul26_Camp_Occupancy_Report.csv"
    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Report saved to: $outputFile" -ForegroundColor Green
    
    # Check if Jul26 data exists in ContractRoomInstallments
    Write-Host ""
    Write-Host "================================" -ForegroundColor Yellow
    Write-Host "Checking Jul26 Data Availability" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow
    
    $checkQuery = "SELECT COUNT(*) AS RecordCount FROM ContractRoomInstallments WHERE Month = 'Jul26' AND ISNULL(IsDeleted, 0) = 0"
    $checkCmd = New-Object System.Data.SqlClient.SqlCommand($checkQuery, $connection)
    $checkReader = $checkCmd.ExecuteReader()
    
    if ($checkReader.Read()) {
        $recordCount = $checkReader["RecordCount"]
        Write-Host "Jul26 Records in ContractRoomInstallments: $recordCount" -ForegroundColor $(if ($recordCount -gt 0) { "Green" } else { "Red" })
        
        if ($recordCount -eq 0) {
            Write-Host ""
            Write-Host "WARNING: No records found for Jul26!" -ForegroundColor Red
            Write-Host "This means all rooms will show as Vacant for July 2026." -ForegroundColor Red
        }
    }
    
    $checkReader.Close()
    $connection.Close()
    
    Write-Host ""
    Write-Host "Connection closed." -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
