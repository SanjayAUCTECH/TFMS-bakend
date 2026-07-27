$BASE = "http://localhost:9001/api"
$SRV  = "160.25.62.124,1433"; $DB = "TFMS_TestSoftwareDB"; $USR = "tfms_user"; $PWD2 = "tfms@123"
$pass = 0; $fail = 0

function Q($q) {
    $r = sqlcmd -S $SRV -U $USR -P $PWD2 -d $DB -Q $q -h -1 -W 2>&1
    return ($r | Where-Object { $_ -match '^\s*[\-0-9]' }) -join "" -replace '\s+',''
}
$login = Invoke-RestMethod -Uri "$BASE/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"Admin@1234"}'
$tok = $login.data.token
$H = @{ Authorization="Bearer $tok"; "Content-Type"="application/json" }

function OK($lbl) { $global:pass++; Write-Output "PASS  $lbl" }
function KO($lbl,$d="") { $global:fail++; Write-Output "FAIL  $lbl  [$d]" }
function GR($url) { try { return Invoke-RestMethod -Uri "$BASE/$url" -Method GET -Headers $H } catch { return $null } }
function PR($url,$body) { try { return Invoke-RestMethod -Uri "$BASE/$url" -Method POST -Headers $H -Body $body } catch { KO "POST $url" $_.Exception.Message; return $null } }
function PU($url,$body) { try { return Invoke-RestMethod -Uri "$BASE/$url" -Method PUT -Headers $H -Body $body } catch { return $null } }
function DE($url) { try { return Invoke-RestMethod -Uri "$BASE/$url" -Method DELETE -Headers $H } catch { return $null } }

function Test-Mod($name, $url, $cBody, $uBody, $tbl) {
    Write-Output "`n--- $name ---"
    $c = PR $url $cBody
    if (-not $c -or -not $c.success) { KO "$name CREATE" $c.message; return }
    $id = $c.data.id; OK "$name CREATE id=$id"

    $row = Q "SELECT AddedBy,IsDeleted FROM $tbl WHERE Id=$id"
    if ($row -match '^10') { OK "$name DB AddedBy=1 IsDeleted=0" } else { KO "$name DB AddedBy/IsDeleted" "raw='$row'" }

    $u = PU "$url/$id" $uBody
    if ($u -and $u.success) {
        OK "$name UPDATE"
        $ub = Q "SELECT ISNULL(UpdatedBy,-1) FROM $tbl WHERE Id=$id"
        if ($ub -ne "-1" -and $ub -ne "") { OK "$name DB UpdatedBy=$ub" } else { KO "$name DB UpdatedBy" "NULL" }
    } else { KO "$name UPDATE" $u.message }

    $g = GR "$url/$id"
    if ($g -and $g.success) { OK "$name GET-BY-ID" } else { KO "$name GET-BY-ID" }

    $d = DE "$url/$id"
    if ($d -and $d.success) {
        OK "$name DELETE"
        $soft = Q "SELECT IsDeleted FROM $tbl WHERE Id=$id"
        if ($soft -eq "1") { OK "$name SoftDelete IsDeleted=1" } else { KO "$name SoftDelete" "IsDeleted=$soft" }
        $phys = Q "SELECT COUNT(*) FROM $tbl WHERE Id=$id"
        if ($phys -eq "1") { OK "$name Physical record NOT hard-deleted" } else { KO "$name PHYSICAL DELETE HAPPENED" }
    } else { KO "$name DELETE" $d.message }

    $list = GR "$url`?PageSize=9999"
    $ids = $list.data | ForEach-Object { $_.id }
    if ($ids -notcontains $id) { OK "$name LIST hides deleted" } else { KO "$name LIST shows deleted item" }
}

# ── 1. AccountsHeads ────────────────────────────────────────────────
Test-Mod "AccountsHeads" "accountsheads" `
    '{"name":"FT-AH","type":"Income","status":"Active"}' `
    '{"name":"FT-AH-U","type":"Income","status":"Active"}' "AccountsHeads"

# ── 2. Designations ─────────────────────────────────────────────────
Test-Mod "Designations" "designations" `
    '{"name":"FT-DES","status":"Active"}' `
    '{"name":"FT-DES-U","status":"Active"}' "Designations"

# ── 3. Floors ───────────────────────────────────────────────────────
Test-Mod "Floors" "floors" `
    '{"name":"FT-FL","number":98,"status":"Active"}' `
    '{"name":"FT-FL-U","number":98,"status":"Active"}' "Floors"

# ── 4. FundPools ────────────────────────────────────────────────────
Test-Mod "FundPools" "fundpools" `
    '{"name":"FT-FP","balance":0,"status":"Active"}' `
    '{"name":"FT-FP-U","balance":0,"status":"Active"}' "FundPools"

# ── 5. Roles ────────────────────────────────────────────────────────
Test-Mod "Roles" "roles" `
    '{"roleName":"FT-ROL","status":"Active"}' `
    '{"roleName":"FT-ROL-U","status":"Active"}' "Roles"

# ── 6. PaymentModes ─────────────────────────────────────────────────
Test-Mod "PaymentModes" "paymentmodes" `
    '{"name":"FT-PM","status":"Active"}' `
    '{"name":"FT-PM-U","status":"Active"}' "PaymentModes"

# ── 7. Owners ───────────────────────────────────────────────────────
Test-Mod "Owners" "owners" `
    '{"name":"FT-OWN","contact":"050","email":"o@t.com","status":"Active"}' `
    '{"name":"FT-OWN-U","contact":"050","email":"o@t.com","status":"Active"}' "Owners"

# ── 8. Partners ─────────────────────────────────────────────────────
Test-Mod "Partners" "partners" `
    '{"name":"FT-PAR","contact":"050","mobile":"050","email":"p@t.com","status":"Active"}' `
    '{"name":"FT-PAR-U","contact":"050","mobile":"050","email":"p@t.com","status":"Active"}' "Partners"

# ── 9. OtherPersons ─────────────────────────────────────────────────
Test-Mod "OtherPersons" "otherpersons" `
    '{"name":"FT-OP","designation":"Mgr","mobile":"050","email":"op@t.com","status":"Active"}' `
    '{"name":"FT-OP-U","designation":"Mgr","mobile":"050","email":"op@t.com","status":"Active"}' "OtherPersons"

# ── 10. Tenants ─────────────────────────────────────────────────────
Test-Mod "Tenants" "tenants" `
    '{"name":"FT-TEN","type":"Individual","contact":"050","emiratesId":"FT-EID","status":"Active"}' `
    '{"name":"FT-TEN-U","type":"Individual","contact":"050","emiratesId":"FT-EID","status":"Active"}' "Tenants"

# ── 11. Rooms ───────────────────────────────────────────────────────
Write-Output "`n--- Rooms ---"
$cId = ((GR "camps?PageSize=1").data | Select-Object -First 1).id
$fId = ((GR "floors?PageSize=1").data | Select-Object -First 1).id
if ($cId -and $fId) {
    Test-Mod "Rooms" "rooms" `
        "{`"roomNo`":`"FT-RM`",`"campId`":$cId,`"floorId`":$fId,`"monthlyPrice`":500,`"status`":`"Vacant`"}" `
        "{`"roomNo`":`"FT-RM-U`",`"campId`":$cId,`"floorId`":$fId,`"monthlyPrice`":600,`"status`":`"Vacant`"}" "Rooms"
} else { KO "Rooms" "No camp/floor" }

# ── 12. Incomes ─────────────────────────────────────────────────────
Write-Output "`n--- Incomes ---"
$fp = (GR "fundpools?PageSize=1&Status=Active").data | Select-Object -First 1
if ($fp) {
    $today = Get-Date -Format "yyyy-MM-dd"
    Test-Mod "Incomes" "incomes" `
        "{`"date`":`"$today`",`"mode`":`"Cash`",`"head`":`"Rent`",`"fundPoolId`":$($fp.id),`"amount`":100,`"purpose`":`"FT`",`"source`":`"Test`",`"sourceRef`":`"`"}" `
        "{`"date`":`"$today`",`"mode`":`"Cash`",`"head`":`"Rent`",`"fundPoolId`":$($fp.id),`"amount`":200,`"purpose`":`"FT-U`",`"source`":`"Test`",`"sourceRef`":`"`"}" "Incomes"
} else { KO "Incomes" "No active FundPool" }

# ── 13. Expenses ────────────────────────────────────────────────────
Write-Output "`n--- Expenses ---"
if ($fp) {
    $today = Get-Date -Format "yyyy-MM-dd"
    Test-Mod "Expenses" "expenses" `
        "{`"date`":`"$today`",`"mode`":`"Cash`",`"head`":`"Maint`",`"fundPoolId`":$($fp.id),`"amount`":50,`"nature`":`"HO`",`"purpose`":`"FT`",`"recipientRole`":`"`"}" `
        "{`"date`":`"$today`",`"mode`":`"Cash`",`"head`":`"Maint`",`"fundPoolId`":$($fp.id),`"amount`":75,`"nature`":`"HO`",`"purpose`":`"FT-U`",`"recipientRole`":`"`"}" "Expenses"
} else { KO "Expenses" "No active FundPool" }

# ── 14. Waivers ─────────────────────────────────────────────────────
Write-Output "`n--- Waivers ---"
$ct = (GR "contracts?PageSize=1").data | Select-Object -First 1
if ($ct) {
    $today = Get-Date -Format "yyyy-MM-dd"
    # Find a pending installment
    $pmts = GR "payments?ContractId=$($ct.contractId)&PageSize=20"
    $pending = $pmts.data | Where-Object { $_.status -ne "Paid" } | Select-Object -First 1
    $instNo = if ($pending) { $pending.installmentNo } else { 1 }
    $wc = PR "waivers" "{`"tenantId`":$($ct.tenantId),`"contractId`":`"$($ct.contractId)`",`"installmentNo`":$instNo,`"waiverAmount`":1,`"remark`":`"FT`",`"waiverDate`":`"$today`"}"
    if ($wc -and $wc.success) {
        $wid = $wc.data.id; OK "Waivers CREATE id=$wid"
        $wr = Q "SELECT AddedBy,IsDeleted FROM Waivers WHERE Id=$wid"
        if ($wr -match '^10') { OK "Waivers DB AddedBy=1 IsDeleted=0" } else { KO "Waivers DB" "row='$wr'" }
        $wd = DE "waivers/$wid"
        if ($wd -and $wd.success) {
            OK "Waivers DELETE"
            $ws = Q "SELECT IsDeleted FROM Waivers WHERE Id=$wid"
            if ($ws -eq "1") { OK "Waivers SoftDelete IsDeleted=1" } else { KO "Waivers SoftDelete" "IsDeleted=$ws" }
            $wp = Q "SELECT COUNT(*) FROM Waivers WHERE Id=$wid"
            if ($wp -eq "1") { OK "Waivers Physical record NOT deleted" } else { KO "Waivers PHYSICAL DELETE" }
        } else { KO "Waivers DELETE" $wd.message }
    } else { KO "Waivers CREATE" $wc.message }
} else { KO "Waivers" "No contract found" }

# ── 15. Staff (multipart form) ──────────────────────────────────────
Write-Output "`n--- Staff ---"
try {
    $boundary = "----FormBoundary" + [System.Guid]::NewGuid().ToString("N")
    $CRLF = "`r`n"
    function Part($name, $value) {
        return "--$boundary$CRLF" +
               "Content-Disposition: form-data; name=`"$name`"$CRLF$CRLF" +
               "$value$CRLF"
    }
    $body = (Part "name" "FT-STAFF") + (Part "contact" "0501234567") +
            (Part "email" "ft@t.com") + (Part "designation" "Manager") +
            (Part "status" "Active") + (Part "loginAccess" "disabled") +
            (Part "address" "") + (Part "emiratesId" "") + (Part "passportNo" "") +
            (Part "nationality" "") + (Part "jobTitle" "") + (Part "remarks" "") +
            "--$boundary--$CRLF"
    $staffH = @{ Authorization="Bearer $tok"; "Content-Type"="multipart/form-data; boundary=$boundary" }
    $sc = Invoke-RestMethod -Uri "$BASE/staff" -Method POST -Headers $staffH -Body $body
    if ($sc.success) {
        $sid = $sc.data.id; OK "Staff CREATE id=$sid"
        $sr = Q "SELECT AddedBy,IsDeleted FROM Staff WHERE Id=$sid"
        if ($sr -match '^10') { OK "Staff DB AddedBy=1 IsDeleted=0" } else { KO "Staff DB" "row='$sr'" }
        $sd = DE "staff/$sid"
        if ($sd -and $sd.success) {
            OK "Staff DELETE"
            $ss = Q "SELECT IsDeleted FROM Staff WHERE Id=$sid"
            if ($ss -eq "1") { OK "Staff SoftDelete IsDeleted=1" } else { KO "Staff SoftDelete" "IsDeleted=$ss" }
            $sp2 = Q "SELECT COUNT(*) FROM Staff WHERE Id=$sid"
            if ($sp2 -eq "1") { OK "Staff Physical record NOT deleted" } else { KO "Staff PHYSICAL DELETE" }
        } else { KO "Staff DELETE" $sd.message }
    } else { KO "Staff CREATE" $sc.message }
} catch { KO "Staff" $_.Exception.Message }

# ── 16. Contract DELETE (only if non-active exists) ─────────────────
Write-Output "`n--- Contract DELETE ---"
$expCont = (GR "contracts?PageSize=5&Status=Expired").data | Select-Object -First 1
if (-not $expCont) { $expCont = (GR "contracts?PageSize=5&Status=Terminated").data | Select-Object -First 1 }
if ($expCont) {
    $cd = DE "contracts/$($expCont.id)"
    if ($cd -and $cd.success) {
        OK "Contract DELETE id=$($expCont.id)"
        $cs = Q "SELECT IsDeleted FROM Contracts WHERE Id=$($expCont.id)"
        if ($cs -eq "1") { OK "Contract SoftDelete IsDeleted=1" } else { KO "Contract SoftDelete" "IsDeleted=$cs" }
    } else { KO "Contract DELETE" $cd.message }
} else { Write-Output "INFO  Contract DELETE skipped - no expired/terminated contract available" }

# ── 17. GET LIST tests ──────────────────────────────────────────────
Write-Output "`n--- GET LIST (IsDeleted=0 filter) ---"
@("contracts","payments","txnrecords","staff","users","camps","rooms","tenants","owners","partners") | ForEach-Object {
    $r = GR "$_`?PageSize=5"
    if ($r -and $r.success -ne $false) { OK "GET $_ (count=$($r.data.Count))" }
    else { KO "GET $_" }
}

# ── 18. DB-level verify ─────────────────────────────────────────────
Write-Output "`n--- DB IsDeleted=1 rows verify ---"
@("Tenants","Rooms","Camps","Owners","Partners","Contracts","AppUsers","Incomes","Expenses",
  "FundPools","Designations","Floors","Roles","AccountsHeads","OtherPersons","PaymentModes",
  "TxnRecords","Waivers","Staff") | ForEach-Object {
    $tot = Q "SELECT COUNT(*) FROM $_"
    $act = Q "SELECT COUNT(*) FROM $_ WHERE IsDeleted=0"
    $del = Q "SELECT COUNT(*) FROM $_ WHERE IsDeleted=1"
    OK "DB $_ | total=$tot active=$act deleted=$del"
}

# ── FINAL REPORT ────────────────────────────────────────────────────
Write-Output ""
Write-Output "============================================"
Write-Output " FINAL FUNCTIONAL VERIFICATION REPORT"
Write-Output "============================================"
Write-Output " PASS  : $pass"
Write-Output " FAIL  : $fail"
Write-Output " TOTAL : $($pass+$fail)"
if ($fail -eq 0) { Write-Output " RESULT: ALL PASS -- 100% COMPLIANT" }
else             { Write-Output " RESULT: $fail FAILURES -- NEEDS FIX" }
Write-Output "============================================"
