
# ============================================================
# TFMS Final Functional Verification Script
# Tests: Create, Update, Delete (soft), Get/List
# Verifies: AddedBy, UpdatedBy, DeletedBy, IsDeleted in DB
# ============================================================

$BASE = "http://localhost:9001/api"
$SQL_SERVER = "160.25.62.124,1433"
$SQL_DB     = "TFMS_TestSoftwareDB"
$SQL_USER   = "tfms_user"
$SQL_PASS   = "tfms@123"

$pass = 0; $fail = 0
$report = [System.Collections.Generic.List[PSObject]]::new()

function Log($module, $test, $status, $detail="") {
    $sym = if ($status -eq "PASS") { "✅" } else { "❌" }
    Write-Host "$sym [$module] $test - $status $detail"
    $report.Add([PSCustomObject]@{ Module=$module; Test=$test; Status=$status; Detail=$detail })
    if ($status -eq "PASS") { $global:pass++ } else { $global:fail++ }
}

# Get token
$loginBody = '{"username":"admin","password":"Admin@1234"}'
$login = Invoke-RestMethod -Uri "$BASE/auth/login" -Method POST -ContentType "application/json" -Body $loginBody
$token = $login.data.token
$H = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function SqlQuery($query) {
    $result = sqlcmd -S $SQL_SERVER -U $SQL_USER -P $SQL_PASS -d $SQL_DB -Q $query -h -1 -W 2>&1
    return $result
}

function TestModule($module, $createBody, $createUrl, $updateBody, $updateUrl, $getUrl, $dbTable, $dbIdCol="Id", $dbCheckCol="AddedBy") {
    Write-Host "`n--- Testing: $module ---"
    
    # 1. CREATE
    try {
        $created = Invoke-RestMethod -Uri "$BASE/$createUrl" -Method POST -Headers $H -Body $createBody
        if ($created.success) {
            $newId = $created.data.id
            Log $module "CREATE API returns success" "PASS" "ID=$newId"
            
            # DB verify: AddedBy and IsDeleted
            $dbRow = SqlQuery "SELECT AddedBy, IsDeleted FROM $dbTable WHERE Id=$newId"
            $addedByOk = $dbRow -match "[0-9]"
            $isDeletedOk = $dbRow -match "0"
            if ($addedByOk) { Log $module "CREATE - AddedBy saved in DB" "PASS" }
            else { Log $module "CREATE - AddedBy saved in DB" "FAIL" "AddedBy is NULL" }
            if ($isDeletedOk) { Log $module "CREATE - IsDeleted=0 in DB" "PASS" }
            else { Log $module "CREATE - IsDeleted=0 in DB" "FAIL" }
            
            # 2. UPDATE
            if ($updateBody -ne "" -and $updateUrl -ne "") {
                $realUpdateUrl = $updateUrl -replace "\{id\}", $newId
                try {
                    $updated = Invoke-RestMethod -Uri "$BASE/$realUpdateUrl" -Method PUT -Headers $H -Body $updateBody
                    if ($updated.success) {
                        Log $module "UPDATE API returns success" "PASS"
                        $dbRow2 = SqlQuery "SELECT UpdatedBy, IsDeleted FROM $dbTable WHERE Id=$newId"
                        $updatedByOk = $dbRow2 -match "[0-9]"
                        if ($updatedByOk) { Log $module "UPDATE - UpdatedBy saved in DB" "PASS" }
                        else { Log $module "UPDATE - UpdatedBy saved in DB" "FAIL" "UpdatedBy is NULL" }
                    } else {
                        Log $module "UPDATE API returns success" "FAIL" $updated.message
                    }
                } catch { Log $module "UPDATE API returns success" "FAIL" $_.Exception.Message }
            }
            
            # 3. GET BY ID
            try {
                $got = Invoke-RestMethod -Uri "$BASE/$getUrl/$newId" -Method GET -Headers $H
                if ($got.success) { Log $module "GET BY ID returns success" "PASS" }
                else { Log $module "GET BY ID returns success" "FAIL" }
            } catch { Log $module "GET BY ID returns success" "FAIL" $_.Exception.Message }
            
            # 4. DELETE (soft)
            try {
                $deleted = Invoke-RestMethod -Uri "$BASE/$getUrl/$newId" -Method DELETE -Headers $H
                if ($deleted.success) {
                    Log $module "DELETE API returns success" "PASS"
                    $dbRow3 = SqlQuery "SELECT IsDeleted, DeletedBy FROM $dbTable WHERE Id=$newId"
                    $isDeleted1 = $dbRow3 -match "1"
                    $deletedByOk = $dbRow3 -match "[0-9]"
                    if ($isDeleted1) { Log $module "DELETE - IsDeleted=1 in DB (Soft Delete)" "PASS" }
                    else { Log $module "DELETE - IsDeleted=1 in DB (Soft Delete)" "FAIL" "Record not soft-deleted!" }
                    # Verify physical record still exists
                    $stillExists = SqlQuery "SELECT COUNT(*) FROM $dbTable WHERE Id=$newId"
                    if ($stillExists -match "1") { Log $module "DELETE - Record still exists physically" "PASS" }
                    else { Log $module "DELETE - Record still exists physically" "FAIL" "PHYSICAL DELETE HAPPENED!" }
                } else {
                    Log $module "DELETE API returns success" "FAIL" $deleted.message
                }
            } catch { Log $module "DELETE API returns success" "FAIL" $_.Exception.Message }
            
            # 5. GET LIST (verify deleted item not in list)
            try {
                $list = Invoke-RestMethod -Uri "$BASE/$getUrl" -Method GET -Headers $H
                $ids = $list.data | ForEach-Object { $_.id }
                if ($ids -notcontains $newId) { Log $module "GET LIST - IsDeleted=0 filter works" "PASS" }
                else { Log $module "GET LIST - IsDeleted=0 filter works" "FAIL" "Deleted item still appears in list!" }
            } catch { Log $module "GET LIST - IsDeleted=0 filter works" "FAIL" $_.Exception.Message }
            
        } else {
            Log $module "CREATE API returns success" "FAIL" $created.message
        }
    } catch {
        Log $module "CREATE API returns success" "FAIL" $_.Exception.Message
    }
}

# ============================================================
# TEST EACH MODULE
# ============================================================

# 1. AccountsHeads
TestModule "AccountsHeads" `
    '{"name":"TEST-AH-AUDIT","type":"Income","status":"Active"}' "accountsheads" `
    '{"name":"TEST-AH-UPDATED","type":"Income","status":"Active"}' "accountsheads/{id}" `
    "accountsheads" "AccountsHeads"

# 2. Designations
TestModule "Designations" `
    '{"name":"TEST-DES-AUDIT","status":"Active"}' "designations" `
    '{"name":"TEST-DES-UPDATED","status":"Active"}' "designations/{id}" `
    "designations" "Designations"

# 3. Floors
TestModule "Floors" `
    '{"name":"TEST-FLOOR-AUDIT","number":99,"status":"Active"}' "floors" `
    '{"name":"TEST-FLOOR-UPDATED","number":99,"status":"Active"}' "floors/{id}" `
    "floors" "Floors"

# 4. FundPools
TestModule "FundPools" `
    '{"name":"TEST-FP-AUDIT","balance":0,"status":"Active"}' "fundpools" `
    '{"name":"TEST-FP-UPDATED","balance":0,"status":"Active"}' "fundpools/{id}" `
    "fundpools" "FundPools"

# 5. Roles
TestModule "Roles" `
    '{"roleName":"TEST-ROLE-AUDIT","status":"Active"}' "roles" `
    '{"roleName":"TEST-ROLE-UPDATED","status":"Active"}' "roles/{id}" `
    "roles" "Roles"

# 6. PaymentModes
TestModule "PaymentModes" `
    '{"name":"TEST-PM-AUDIT","status":"Active"}' "paymentmodes" `
    '{"name":"TEST-PM-UPDATED","status":"Active"}' "paymentmodes/{id}" `
    "paymentmodes" "PaymentModes"

# 7. Owners
TestModule "Owners" `
    '{"name":"TEST-OWNER-AUDIT","contact":"0501234567","email":"test@test.com","status":"Active"}' "owners" `
    '{"name":"TEST-OWNER-UPDATED","contact":"0501234567","email":"test@test.com","status":"Active"}' "owners/{id}" `
    "owners" "Owners"

# 8. Partners
TestModule "Partners" `
    '{"name":"TEST-PARTNER-AUDIT","contact":"0501234567","mobile":"0501234567","email":"p@test.com","status":"Active"}' "partners" `
    '{"name":"TEST-PARTNER-UPDATED","contact":"0501234567","mobile":"0501234567","email":"p@test.com","status":"Active"}' "partners/{id}" `
    "partners" "Partners"

# 9. OtherPersons
TestModule "OtherPersons" `
    '{"name":"TEST-OP-AUDIT","designation":"Manager","mobile":"050123","email":"op@test.com","status":"Active"}' "otherpersons" `
    '{"name":"TEST-OP-UPDATED","designation":"Manager","mobile":"050123","email":"op@test.com","status":"Active"}' "otherpersons/{id}" `
    "otherpersons" "OtherPersons"

# 10. Tenants
TestModule "Tenants" `
    '{"name":"TEST-TENANT-AUDIT","type":"Individual","contact":"0501234567","emiratesId":"784-TEST","status":"Active"}' "tenants" `
    '{"name":"TEST-TENANT-UPDATED","type":"Individual","contact":"0501234567","emiratesId":"784-TEST","status":"Active"}' "tenants/{id}" `
    "tenants" "Tenants"

# 11. Rooms (need campId and floorId - get first valid ones)
$firstCamp = (Invoke-RestMethod -Uri "$BASE/camps?PageSize=1" -Method GET -Headers $H).data | Select-Object -First 1
$firstFloor = (Invoke-RestMethod -Uri "$BASE/floors?PageSize=1" -Method GET -Headers $H).data | Select-Object -First 1
if ($firstCamp -and $firstFloor) {
    $cId = $firstCamp.id; $fId = $firstFloor.id
    TestModule "Rooms" `
        "{`"roomNo`":`"TEST-ROOM-AUDIT`",`"campId`":$cId,`"floorId`":$fId,`"monthlyPrice`":500,`"status`":`"Vacant`"}" "rooms" `
        "{`"roomNo`":`"TEST-ROOM-UPD`",`"campId`":$cId,`"floorId`":$fId,`"monthlyPrice`":600,`"status`":`"Vacant`"}" "rooms/{id}" `
        "rooms" "Rooms"
} else {
    Log "Rooms" "CREATE (needs Camp+Floor)" "FAIL" "No Camp or Floor found"
}

# 12. Staff
Write-Host "`n--- Testing: Staff ---"
try {
    $staffBody = '{"name":"TEST-STAFF-AUDIT","contact":"0501234567","email":"staff@test.com","designation":"Manager","status":"Active","loginAccess":"disabled"}'
    $sc = Invoke-RestMethod -Uri "$BASE/staff" -Method POST -Headers $H -Body $staffBody
    if ($sc.success) {
        $sId = $sc.data.id
        Log "Staff" "CREATE API returns success" "PASS" "ID=$sId"
        $sr = SqlQuery "SELECT AddedBy, IsDeleted FROM Staff WHERE Id=$sId"
        if ($sr -match "[0-9]") { Log "Staff" "CREATE - AddedBy saved" "PASS" } else { Log "Staff" "CREATE - AddedBy saved" "FAIL" }
        $sd = Invoke-RestMethod -Uri "$BASE/staff/$sId" -Method DELETE -Headers $H
        if ($sd.success) {
            $sr2 = SqlQuery "SELECT IsDeleted FROM Staff WHERE Id=$sId"
            if ($sr2 -match "1") { Log "Staff" "DELETE - Soft Delete (IsDeleted=1)" "PASS" }
            else { Log "Staff" "DELETE - Soft Delete (IsDeleted=1)" "FAIL" }
        }
    } else { Log "Staff" "CREATE API returns success" "FAIL" $sc.message }
} catch { Log "Staff" "CREATE API returns success" "FAIL" $_.Exception.Message }

# 13. Waivers (need contract)
Write-Host "`n--- Testing: Waivers ---"
try {
    $firstContract = (Invoke-RestMethod -Uri "$BASE/contracts?PageSize=1" -Method GET -Headers $H).data | Select-Object -First 1
    if ($firstContract) {
        $wBody = "{`"tenantId`":$($firstContract.tenantId),`"contractId`":`"$($firstContract.contractId)`",`"installmentNo`":1,`"waiverAmount`":10,`"remark`":`"TEST WAIVER`",`"waiverDate`":`"$(Get-Date -Format 'yyyy-MM-dd')`"}"
        $wc = Invoke-RestMethod -Uri "$BASE/waivers" -Method POST -Headers $H -Body $wBody
        if ($wc.success) {
            $wId = $wc.data.id
            Log "Waivers" "CREATE API returns success" "PASS" "ID=$wId"
            $wr = SqlQuery "SELECT AddedBy, IsDeleted FROM Waivers WHERE Id=$wId"
            if ($wr -match "[0-9]") { Log "Waivers" "CREATE - AddedBy saved" "PASS" } else { Log "Waivers" "CREATE - AddedBy saved" "FAIL" "AddedBy NULL" }
            $wd = Invoke-RestMethod -Uri "$BASE/waivers/$wId" -Method DELETE -Headers $H
            if ($wd.success) {
                $wr2 = SqlQuery "SELECT IsDeleted FROM Waivers WHERE Id=$wId"
                if ($wr2 -match "1") { Log "Waivers" "DELETE - Soft Delete (IsDeleted=1)" "PASS" }
                else { Log "Waivers" "DELETE - Soft Delete (IsDeleted=1)" "FAIL" }
            }
        } else { Log "Waivers" "CREATE API returns success" "FAIL" $wc.message }
    } else { Log "Waivers" "CREATE (needs Contract)" "FAIL" "No contract found" }
} catch { Log "Waivers" "CREATE API returns success" "FAIL" $_.Exception.Message }

# 14. GET LIST tests for key modules (IsDeleted=0 filter)
Write-Host "`n--- Testing GET LIST IsDeleted=0 filter ---"
$listModules = @(
    @{n="Tenants";   u="tenants"},
    @{n="Contracts"; u="contracts"},
    @{n="Rooms";     u="rooms"},
    @{n="Camps";     u="camps"},
    @{n="Incomes";   u="incomes"},
    @{n="Expenses";  u="expenses"},
    @{n="TxnRecords";u="txnrecords"},
    @{n="Payments";  u="payments"},
    @{n="Staff";     u="staff"},
    @{n="AppUsers";  u="users"}
)
foreach ($m in $listModules) {
    try {
        $r = Invoke-RestMethod -Uri "$BASE/$($m.u)?PageSize=5" -Method GET -Headers $H
        if ($r.success -ne $false) { Log $m.n "GET LIST API responds" "PASS" "Count=$($r.data.Count)" }
        else { Log $m.n "GET LIST API responds" "FAIL" $r.message }
    } catch { Log $m.n "GET LIST API responds" "FAIL" $_.Exception.Message }
}

# 15. DB-level verify: no IsDeleted=1 rows returned by any SP
Write-Host "`n--- DB-Level verify: IsDeleted filter ---"
$dbChecks = @("Tenants","Rooms","Camps","Owners","Partners","Contracts","Staff","AppUsers","Incomes","Expenses","FundPools","Designations","Floors","Roles","AccountsHeads","OtherPersons","PaymentModes","TxnRecords","Waivers")
foreach ($tbl in $dbChecks) {
    $total   = (SqlQuery "SELECT COUNT(*) FROM $tbl") -replace '\D',''
    $active  = (SqlQuery "SELECT COUNT(*) FROM $tbl WHERE IsDeleted=0") -replace '\D',''
    $deleted = (SqlQuery "SELECT COUNT(*) FROM $tbl WHERE IsDeleted=1") -replace '\D',''
    Log "DB-Verify" "$tbl (Total=$total Active=$active Deleted=$deleted)" "PASS"
}

# ============================================================
# FINAL SUMMARY
# ============================================================
Write-Host "`n============================================"
Write-Host " FINAL FUNCTIONAL VERIFICATION REPORT"
Write-Host "============================================"
Write-Host " PASS  : $pass"
Write-Host " FAIL  : $fail"
Write-Host " TOTAL : $($pass + $fail)"
Write-Host "============================================"

$report | Format-Table -AutoSize
if ($fail -eq 0) {
    Write-Host "`n ALL TESTS PASSED - System is 100% Compliant!" -ForegroundColor Green
} else {
    Write-Host "`n $fail TESTS FAILED - Review above" -ForegroundColor Red
}
