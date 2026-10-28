# =============================================
# PowerShell Script: Test Month-wise Rental Report Procedures
# Description: Test stored procedures with various filter combinations
# Usage: Run after creating the procedures
# =============================================

# Configuration
$ServerInstance = "DESKTOP-7VNDPC8\SQLEXPRESS"  # Update with your SQL Server instance
$Database = "TFMS"                               # Update with your database name

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Testing Month-wise Rental Report Procedures" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Import SqlServer module
Import-Module SqlServer -ErrorAction SilentlyContinue

# Test 1: Get all records (first page)
Write-Host "Test 1: Get all records (Page 1, Size 10)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql1 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result1 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql1
    Write-Host "✓ Test 1 Passed - Total Records: $($result1.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 1 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Filter by Month
Write-Host "Test 2: Filter by Month (Dec26)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql2 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @Month = 'Dec26',
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result2 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql2
    Write-Host "✓ Test 2 Passed - Records for Dec26: $($result2.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 2 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Filter by Status
Write-Host "Test 3: Filter by Status (Pending)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql3 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @Status = 'Pending',
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result3 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql3
    Write-Host "✓ Test 3 Passed - Pending Records: $($result3.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 3 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Filter by Camp (if you have CampId)
Write-Host "Test 4: Filter by Camp (CampId = 1)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql4 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @CampId = 1,
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result4 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql4
    Write-Host "✓ Test 4 Passed - Records for Camp 1: $($result4.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 4 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Sorting (by InstallAmount DESC)
Write-Host "Test 5: Sort by InstallAmount DESC" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql5 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @SortBy = 'InstallAmount',
    @SortDirection = 'DESC',
    @PageNumber = 1, 
    @PageSize = 5,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result5 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql5
    Write-Host "✓ Test 5 Passed - Total Records: $($result5.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 5 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Multiple Filters (Month + Status)
Write-Host "Test 6: Multiple Filters (Month + Status)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql6 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @Month = 'Dec26',
    @Status = 'Paid',
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result6 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql6
    Write-Host "✓ Test 6 Passed - Paid records in Dec26: $($result6.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 6 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 7: Monthly Summary Procedure
Write-Host "Test 7: Monthly Summary (All Data)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql7 = "EXEC sp_GetMonthwiseRentalSummary;"

try {
    $result7 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql7
    Write-Host "✓ Test 7 Passed - Months found: $($result7.Count)" -ForegroundColor Green
    
    # Display summary
    if ($result7.Count -gt 0) {
        Write-Host ""
        Write-Host "Monthly Summary:" -ForegroundColor Cyan
        $result7 | Format-Table Month, TotalRooms, TotalInstallments, TotalInstallAmount, TotalPaidAmount -AutoSize
    }
}
catch {
    Write-Host "✗ Test 7 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 8: Summary with filters
Write-Host "Test 8: Monthly Summary (Status = Paid)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql8 = "EXEC sp_GetMonthwiseRentalSummary @Status = 'Paid';"

try {
    $result8 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql8
    Write-Host "✓ Test 8 Passed - Months with paid data: $($result8.Count)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 8 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 9: Date Range Filter
Write-Host "Test 9: Date Range Filter (Current Month)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$firstDay = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Format "yyyy-MM-dd"
$lastDay = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Format "yyyy-MM-dd" | Get-Date
$lastDay = $lastDay.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")

$sql9 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @FromDate = '$firstDay',
    @ToDate = '$lastDay',
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result9 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql9
    Write-Host "✓ Test 9 Passed - Records in date range: $($result9.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 9 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 10: Contract Status Filter
Write-Host "Test 10: Filter by Contract Status (Active)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
$sql10 = @"
DECLARE @TotalRecords INT;
EXEC sp_GetMonthwiseRentalReport 
    @ContractStatus = 'Active',
    @PageNumber = 1, 
    @PageSize = 10,
    @TotalRecords = @TotalRecords OUTPUT;
SELECT @TotalRecords AS TotalRecords;
"@

try {
    $result10 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $sql10
    Write-Host "✓ Test 10 Passed - Active Contract Records: $($result10.TotalRecords)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Test 10 Failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "All tests completed!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Start your backend API" -ForegroundColor White
Write-Host "2. Test endpoints using Swagger or Postman" -ForegroundColor White
Write-Host "3. Verify data with frontend application" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
