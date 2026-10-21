# Run Fund Pool Monthly Balance Setup
$ServerName = "160.25.62.124,1433"
$DatabaseName = "TFMS_TestSoftwareDB"
$Username = "tfms_user"
$Password = "tfms@123"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fund Pool Monthly Balance Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$SqlFile = Join-Path $PSScriptRoot "FundPoolMonthlyBalance_Setup.sql"

if (-not (Test-Path $SqlFile)) {
    Write-Host "ERROR: SQL file not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Connecting to database..." -ForegroundColor Yellow
$ConnectionString = "Server=$ServerName;Database=$DatabaseName;User Id=$Username;Password=$Password;TrustServerCertificate=True;Encrypt=True;"

try {
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()
    Write-Host "Connected successfully!" -ForegroundColor Green
    Write-Host ""

    # Read SQL file
    $SqlContent = Get-Content $SqlFile -Raw
    
    # Split by GO
    $Batches = $SqlContent -split '\r?\nGO\r?\n'
    
    $BatchCount = 0
    $SuccessCount = 0
    
    # Message handler
    $Connection.add_InfoMessage({
        param($sender, $eventArgs)
        $message = $eventArgs.Message
        if ($message -like "*ERROR*") {
            Write-Host $message -ForegroundColor Red
        }
        elseif ($message -like "*Step*") {
            Write-Host $message -ForegroundColor Cyan
        }
        elseif ($message -like "*SUCCESS*") {
            Write-Host $message -ForegroundColor Green
        }
        else {
            Write-Host $message -ForegroundColor White
        }
    })
    $Connection.FireInfoMessageEventOnUserErrors = $true

    foreach ($Batch in $Batches) {
        $Batch = $Batch.Trim()
        if ([string]::IsNullOrWhiteSpace($Batch)) {
            continue
        }
        
        $BatchCount++
        
        try {
            $Command = New-Object System.Data.SqlClient.SqlCommand($Batch, $Connection)
            $Command.CommandTimeout = 300
            $Command.ExecuteNonQuery() | Out-Null
            $SuccessCount++
        }
        catch {
            Write-Host "Error in batch $BatchCount : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Setup Completed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Total Batches: $BatchCount" -ForegroundColor White
    Write-Host "  Successful: $SuccessCount" -ForegroundColor Green
    Write-Host ""
    Write-Host "Table Created: FundPoolMonthlyBalances" -ForegroundColor Cyan
    Write-Host "Procedures Created:" -ForegroundColor Cyan
    Write-Host "  - sp_SaveFundPoolMonthlyBalance" -ForegroundColor White
    Write-Host "  - sp_GetFundPoolMonthlyBalance" -ForegroundColor White
    Write-Host "  - sp_GetAllFundPoolMonthlyBalances" -ForegroundColor White
    Write-Host "  - sp_DeleteFundPoolMonthlyBalance" -ForegroundColor White
    Write-Host ""

    $Connection.Close()
    $Connection.Dispose()

} catch {
    Write-Host ""
    Write-Host "ERROR: Setup Failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
