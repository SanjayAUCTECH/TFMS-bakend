$base = "http://localhost:9001"
$tok = (Invoke-RestMethod -Uri "$base/api/auth/login" -Method POST -Body '{"username":"admin","password":"Admin@1234"}' -ContentType "application/json").data.token
$H = @{ Authorization = "Bearer $tok" }
$ok = 0; $fail = 0
$outLines = [System.Collections.Generic.List[string]]::new()

function TG($path) {
    try {
        $j = Invoke-RestMethod -Uri "$base/api/$path" -Headers $H
        $script:ok++
        $script:outLines.Add("OK   GET $path")
    } catch {
        $script:fail++
        $e = $_.ErrorDetails.Message; if (!$e) { $e = $_.Exception.Message }
        try { $ej = $e | ConvertFrom-Json -EA SilentlyContinue; if ($ej.message) { $e = $ej.message } } catch {}
        $script:outLines.Add("FAIL GET $path | $e")
    }
}

function TP($method, $path, $body) {
    try {
        $p = @{ Uri = "$base/api/$path"; Method = $method; Headers = $H }
        if ($body) { $p.Body = $body; $p.ContentType = "application/json" }
        $j = Invoke-RestMethod @p
        $script:ok++
        $script:outLines.Add("OK   $method $path | $($j.message)")
        return $j.data
    } catch {
        $script:fail++
        $e = $_.ErrorDetails.Message; if (!$e) { $e = $_.Exception.Message }
        try { $ej = $e | ConvertFrom-Json -EA SilentlyContinue; if ($ej.message) { $e = $ej.message } } catch {}
        $script:outLines.Add("FAIL $method $path | $e")
        return $null
    }
}

$outLines.Add("===== GET ALL =====")
TG "partners?PageNumber=1&PageSize=3"
TG "owners?PageNumber=1&PageSize=3"
TG "floors?PageNumber=1&PageSize=3"
TG "roomstatuses"
TG "paymentmodes"
TG "fundpools?PageNumber=1&PageSize=3"
TG "accountsheads?PageNumber=1&PageSize=3"
TG "designations?PageNumber=1&PageSize=3"
TG "otherpersons?PageNumber=1&PageSize=3"
TG "roles?PageNumber=1&PageSize=3"
TG "camps?PageNumber=1&PageSize=3"
TG "camps/active"
TG "rooms?PageNumber=1&PageSize=3"
TG "tenants?PageNumber=1&PageSize=3"
TG "contracts?PageNumber=1&PageSize=3"
TG "payments?PageNumber=1&PageSize=3"
TG "waivers?PageNumber=1&PageSize=3"
TG "incomes?PageNumber=1&PageSize=3"
TG "expenses?PageNumber=1&PageSize=3"
TG "staff?PageNumber=1&PageSize=3"
TG "users?PageNumber=1&PageSize=3"
TG "txnrecords?PageNumber=1&PageSize=3"
TG "ownercontracts"
TG "dashboard/stats"
TG "mis/stats"
TG "mis/owner-report?PageNumber=1&PageSize=3"
TG "reports/inventory?PageNumber=1&PageSize=3"
TG "reports/tenants?PageNumber=1&PageSize=3"
TG "reports/due?PageNumber=1&PageSize=3"
TG "reports/transactions?PageNumber=1&PageSize=3"
TG "reports/waivers?PageNumber=1&PageSize=3"

$outLines.Add("")
$outLines.Add("===== INSERT =====")
$pt = TP "POST" "partners"     '{"name":"TP","contact":"0501","mobile":"0501","email":"p@t.com","status":"Active"}'
$ow = TP "POST" "owners"       '{"name":"TO","contact":"0502","email":"o@t.com","status":"Active"}'
$fl = TP "POST" "floors"       '{"name":"TF","number":9,"status":"Active"}'
$fp = TP "POST" "fundpools"    '{"name":"FP-T","balance":0,"status":"Active"}'
$ah = TP "POST" "accountsheads" '{"name":"AH-T","type":"Income","status":"Active"}'
$dg = TP "POST" "designations" '{"name":"DG-T","status":"Active"}'
$ro = TP "POST" "roles"        '{"roleName":"RO-T","status":"Active"}'
$campBody = "{`"name`":`"CampT`",`"status`":`"Active`",`"campPropertyUsage`":`"Industrial`",`"campBuildingName`":`"BlkT`",`"campPropertyType`":`"Labour`",`"campLocation`":`"Dubai`",`"campPropertyNo`":`"P1`",`"campPropertyArea`":`"500`",`"campPremisesNo`":`"PR1`",`"campPlotNo`":`"PL1`",`"campMakaniNo`":`"MK1`",`"partners`":[{`"partnerId`":$($pt.id),`"shareType`":`"percentage`",`"shareValue`":100}],`"owners`":[{`"ownerId`":$($ow.id),`"shareType`":`"percentage`",`"shareValue`":100}]}"
$ca = TP "POST" "camps" $campBody
$rm = TP "POST" "rooms" "{`"roomNo`":`"T101`",`"campId`":$($ca.id),`"floorId`":$($fl.id),`"monthlyPrice`":1500,`"status`":`"Vacant`",`"otherDetails`":`"`"}"
$te = TP "POST" "tenants" '{"type":"Individual","name":"TenantT","passport":"P1","nationality":"Indian","emiratesId":"784-1990-1234567-8","contact":"0503","whatsapp":"0503","email":"t@t.com","address":"Dubai","status":"Active","company":"","tradeLicense":"","licensingAuthority":"","numberOfCoOccupants":"1","plotNo":"PL","makaniNo":"MK","propertyArea":"500","premisesNo":"PR","lessorName":"L","lessorEid":"784-1980-1234567-8","lessorLicense":"L1","lessorLicAuthority":"DED","lessorEmail":"l@t.com","lessorPhone":"0504"}'
$ctBody = "{`"tenantId`":$($te.id),`"campId`":$($ca.id),`"startDate`":`"2026-01-01`",`"months`":3,`"roomIds`":[$($rm.id)],`"securityDeposit`":500,`"installmentType`":`"monthly`",`"issuedBy`":`"Admin`",`"notes`":`"Test`",`"lessorAmount`":0,`"contractPropertyUsage`":`"Res`",`"contractBuildingName`":`"B`",`"contractPropertyType`":`"Labour`",`"contractLocation`":`"Dubai`",`"contractPropertyNo`":`"P1`",`"contractPropertyArea`":`"500`",`"contractPremisesNo`":`"PR1`",`"contractPaymentMode`":`"Cash`",`"contractPlotNo`":`"PL1`",`"contractMakaniNo`":`"MK1`"}"
$ct = TP "POST" "contracts" $ctBody
$cid = $ct.contractId
$pyBody = "{`"contractId`":`"$cid`",`"installmentNo`":1,`"paidAmount`":1500,`"paidDate`":`"2026-07-14T00:00:00`",`"paymentModeId`":1,`"paymentMode`":`"Cash`",`"chequeNumber`":`"`",`"clearanceDate`":`"`",`"description`":`"Test`",`"receivedBy`":`"Admin`",`"receivedContact`":`"0501`",`"fundPoolId`":1,`"fundPoolName`":`"Main`",`"issuedBy`":`"Admin`"}"
TP "POST" "payments/record" $pyBody | Out-Null
$inc = TP "POST" "incomes"  '{"date":"2026-07-14","mode":"Cash","head":"Rental Income","fundPoolId":1,"amount":500,"purpose":"Test","source":"Manual","sourceRef":"R1"}'
$exp = TP "POST" "expenses" '{"date":"2026-07-14","mode":"Cash","head":"Salary","fundPoolId":1,"amount":200,"nature":"HO","campId":null,"recipientRole":"Staff","recipientName":"TS","purpose":"Test"}'
$st  = TP "POST" "staff"    '{"name":"StaffT","designation":"Manager","contact":"0501","email":"st@t.com","address":"Dubai","username":"stafft_z99","password":"Test@1234","loginAccess":"enabled","status":"Active","remarks":"","emiratesId":"784-1990-1111111-1","passportNo":"P111","nationality":"Indian","jobTitle":"Manager","moveInDate":"2026-01-01","visaExpiry":"2027-01-01"}'
$ocBody = "{`"campId`":$($ca.id),`"ownerId`":$($ow.id),`"paymentType`":`"monthly`",`"totalAmount`":10000,`"startDate`":`"2026-01-01`",`"installments`":[{`"no`":1,`"amount`":5000,`"dueDate`":`"2026-01-01`"},{`"no`":2,`"amount`":5000,`"dueDate`":`"2026-02-01`"}]}"
$oc = TP "POST" "ownercontracts" $ocBody

$outLines.Add("")
$outLines.Add("===== UPDATE =====")
if ($pt -and $pt.id) { TP "PUT" "partners/$($pt.id)"  '{"name":"TP-U","contact":"1111","mobile":"1111","email":"pu@t.com","status":"Active"}' | Out-Null }
if ($ow -and $ow.id) { TP "PUT" "owners/$($ow.id)"    '{"name":"TO-U","contact":"1111","email":"ou@t.com","status":"Active"}' | Out-Null }
if ($fl -and $fl.id) { TP "PUT" "floors/$($fl.id)"    '{"name":"TF-U","number":9,"status":"Active"}' | Out-Null }
if ($te -and $te.id) { TP "PUT" "tenants/$($te.id)"   '{"type":"Individual","name":"TenantT-U","passport":"P2","nationality":"Pak","emiratesId":"784-1991-9999999-9","contact":"0502","whatsapp":"0502","email":"tu@t.com","address":"SHJ","status":"Active","company":"","tradeLicense":"","licensingAuthority":"","numberOfCoOccupants":"1","plotNo":"P2","makaniNo":"M2","propertyArea":"500","premisesNo":"PR2","lessorName":"L2","lessorEid":"784-1981-9999999-9","lessorLicense":"L2","lessorLicAuthority":"DED","lessorEmail":"lu@t.com","lessorPhone":"0505"}' | Out-Null }
if ($inc -and $inc.id) { TP "PUT" "incomes/$($inc.id)" '{"date":"2026-07-15","mode":"Cheque","head":"Rental Income","fundPoolId":1,"amount":600,"purpose":"Upd","source":"Manual","sourceRef":"R2"}' | Out-Null }
if ($exp -and $exp.id) { TP "PUT" "expenses/$($exp.id)" '{"date":"2026-07-15","mode":"Cheque","head":"Salary","fundPoolId":1,"amount":300,"nature":"HO","campId":null,"recipientRole":"Staff","recipientName":"TS","purpose":"Upd"}' | Out-Null }
if ($st -and $st.id)   { TP "PUT" "staff/$($st.id)"   '{"name":"StaffT-U","designation":"Senior","contact":"0502","email":"stu@t.com","address":"SHJ","username":"stafft_z99","loginAccess":"enabled","status":"Active","remarks":"Upd","emiratesId":"784-1990-2222222-2","passportNo":"P222","nationality":"Pakistani","jobTitle":"Senior","moveInDate":"2026-06-01","visaExpiry":"2028-01-01"}' | Out-Null }
if ($ct -and $ct.contractId) { TP "PATCH" "contracts/$($ct.contractId)/status" '{"status":"Expired"}' | Out-Null }

$outLines.Add("")
$outLines.Add("===== DELETE =====")
if ($oc -and $oc.id)   { TP "DELETE" "ownercontracts/$($oc.id)" $null | Out-Null }
if ($inc -and $inc.id) { TP "DELETE" "incomes/$($inc.id)"  $null | Out-Null }
if ($exp -and $exp.id) { TP "DELETE" "expenses/$($exp.id)" $null | Out-Null }
if ($st -and $st.id)   { TP "DELETE" "staff/$($st.id)"     $null | Out-Null }
if ($ct -and $ct.id)   { TP "DELETE" "contracts/$($ct.id)" $null | Out-Null }
if ($te -and $te.id)   { TP "DELETE" "tenants/$($te.id)"   $null | Out-Null }
if ($rm -and $rm.id)   { TP "DELETE" "rooms/$($rm.id)"     $null | Out-Null }
if ($ca -and $ca.id)   { TP "DELETE" "camps/$($ca.id)"     $null | Out-Null }
if ($pt -and $pt.id)   { TP "DELETE" "partners/$($pt.id)"  $null | Out-Null }
if ($ow -and $ow.id)   { TP "DELETE" "owners/$($ow.id)"    $null | Out-Null }
if ($fl -and $fl.id)   { TP "DELETE" "floors/$($fl.id)"    $null | Out-Null }
if ($fp -and $fp.id)   { TP "DELETE" "fundpools/$($fp.id)" $null | Out-Null }
if ($ah -and $ah.id)   { TP "DELETE" "accountsheads/$($ah.id)" $null | Out-Null }
if ($dg -and $dg.id)   { TP "DELETE" "designations/$($dg.id)"  $null | Out-Null }
if ($ro -and $ro.id)   { TP "DELETE" "roles/$($ro.id)"     $null | Out-Null }

$outLines.Add("")
$outLines.Add("=== FINAL: OK=$ok  FAIL=$fail  TOTAL=$($ok+$fail) ===")
$outFile = "g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend\Scripts\api_test_out.txt"
[System.IO.File]::WriteAllLines($outFile, $outLines)
