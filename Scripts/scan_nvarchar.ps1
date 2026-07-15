$p = "g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend\Scripts"
$files = Get-ChildItem -Path $p -Filter "*.sql"
$out = [System.Collections.Generic.List[object]]::new()
foreach ($f in $files) {
    $lines = Get-Content $f.FullName -Encoding UTF8
    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $ms = [regex]::Matches($line, 'NVARCHAR\((\d+)\)')
        foreach ($m in $ms) {
            $num = [int]$m.Groups[1].Value
            if ($num -ne 450) {
                $out.Add([PSCustomObject]@{
                    File   = $f.Name
                    LineNo = $i+1
                    Size   = $num
                    Line   = $line.Trim()
                })
            }
        }
    }
}
Write-Host "Total fixed-size NVARCHAR (excluding 450): $($out.Count)"
$out | Sort-Object File, LineNo | Format-Table File, LineNo, Size -AutoSize
