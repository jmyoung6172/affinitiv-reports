# Affinitiv Reports — Push Script

$REPO_PATH      = "C:\AffinitivReports"
$REPORTS_SOURCE = "C:\Users\JeffreyYoung\Reports"
$REPORTS_DEST   = "$REPO_PATH\reports"
$EXTENSIONS     = @("*.html", "*.md", "*.xlsx", "*.csv", "*.pdf")

Write-Host ""
Write-Host "Affinitiv Reports Push" -ForegroundColor Cyan
Write-Host "-----------------------------------------" -ForegroundColor DarkGray

if (-not (Test-Path $REPORTS_DEST)) {
    New-Item -ItemType Directory -Path $REPORTS_DEST | Out-Null
}

$copied = 0
$seenCopy = @{}
foreach ($ext in $EXTENSIONS) {
    foreach ($file in (Get-ChildItem -Path $REPORTS_SOURCE -Filter $ext -ErrorAction SilentlyContinue)) {
        if ($seenCopy.ContainsKey($file.Name)) { continue }
        $seenCopy[$file.Name] = $true
        $dest = Join-Path $REPORTS_DEST $file.Name
        $shouldCopy = $true
        if (Test-Path $dest) {
            if ((Get-FileHash $file.FullName -Algorithm MD5).Hash -eq (Get-FileHash $dest -Algorithm MD5).Hash) {
                $shouldCopy = $false
            }
        }
        if ($shouldCopy) {
            Copy-Item $file.FullName -Destination $dest -Force
            Write-Host "  Copied: $($file.Name)" -ForegroundColor Green
            $copied++
        }
    }
}

Write-Host ""
if ($copied -eq 0) { Write-Host "No new reports to push." -ForegroundColor DarkGray }
else { Write-Host "$copied file(s) copied." -ForegroundColor Green }

$seenIndex = @{}
$reportFiles = foreach ($ext in $EXTENSIONS) {
    foreach ($f in (Get-ChildItem -Path $REPORTS_DEST -Filter $ext -ErrorAction SilentlyContinue)) {
        if (-not $seenIndex.ContainsKey($f.Name)) {
            $seenIndex[$f.Name] = $true
            [PSCustomObject]@{ name = $f.Name; modified = $f.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss"); size = $f.Length }
        }
    }
}

$sorted = @($reportFiles | Sort-Object { $_.name } -Descending)
$lines = $sorted | ForEach-Object { "  {`"name`": `"$($_.name)`", `"modified`": `"$($_.modified)`", `"size`": $($_.size)}" }
"[$([Environment]::NewLine)$($lines -join ",`n")$([Environment]::NewLine)]" | Set-Content "$REPORTS_DEST\index.json" -Encoding UTF8

Write-Host "Updated index.json ($($sorted.Count) reports total)" -ForegroundColor Cyan

Set-Location $REPO_PATH
$status = git status --porcelain 2>&1
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Git: Nothing to commit, site is up to date." -ForegroundColor DarkGray
} else {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    git add . 2>&1 | Out-Null
    git commit -m "Reports update $timestamp" 2>&1 | Out-Null
    git push origin main 2>&1
    Write-Host ""
    Write-Host "Pushed to GitHub. Site will update in ~1 minute." -ForegroundColor Green
    Write-Host "URL: https://jmyoung6172.github.io/affinitiv-reports/" -ForegroundColor Cyan
}
Write-Host ""
