$scriptDir = "g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend\Scripts"
$files = Get-ChildItem -Path $scriptDir -Filter "*.sql" | Where-Object { $_.Name -ne "028_NVarCharMaxEverywhere.sql" }

$totalFiles = 0
$totalReplacements = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $original = $content

    $newContent = [regex]::Replace($content, 'NVARCHAR\((?!450\b)(\d+)\)', 'NVARCHAR(MAX)')

    if ($newContent -ne $original) {
        $before = [regex]::Matches($original, 'NVARCHAR\((?!450\b)(\d+)\)').Count
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
        Write-Host "Updated: $($file.Name) - $before replacements" -ForegroundColor Green
        $totalFiles++
        $totalReplacements += $before
    }
}

Write-Host ""
Write-Host "Files updated: $totalFiles, Total replacements: $totalReplacements" -ForegroundColor Cyan
