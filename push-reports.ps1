# Affinitiv Reports â€” Push Script
# Run this after new reports are generated, or schedule it nightly.
# Requirements: Git must be installed and configured on this machine.
#
# SETUP (one time only):
#   1. Clone your GitHub repo to C:\AffinitivReports\
#   2. Set REPO_PATH below to match
#   3. Set REPORTS_SOURCE to wherever Claude saves your outputs

# â”€â”€ CONFIG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$REPO_PATH     = "C:\AffinitivReports"          # Local clone of your GitHub repo
$REPORTS_SOURCE = "C:\\Users\\JeffreyYoung\\Reports"
$REPORTS_DEST  = "$REPO_PATH\reports"            # Subfolder inside the repo
$EXTENSIONS    = @("*.html", "*.md", "*.xlsx", "*.xls", "*.csv", "*.pdf")
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Write-Host ""
Write-Host "Affinitiv Reports Push" -ForegroundColor Cyan
Write-Host "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray

# Ensure reports folder exists
if (-not (Test-Path $REPORTS_DEST)) {
    New-Item -ItemType Directory -Path $REPORTS_DEST | Out-Null
    Write-Host "Created reports folder: $REPORTS_DEST" -ForegroundColor Yellow
}

# Copy new/changed report files
$copied = 0
foreach ($ext in $EXTENSIONS) {
    $files = Get-ChildItem -Path $REPORTS_SOURCE -Filter $ext -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $dest = Join-Path $REPORTS_DEST $file.Name
        $shouldCopy = $true

        if (Test-Path $dest) {
            $srcHash  = (Get-FileHash $file.FullName -Algorithm MD5).Hash
            $destHash = (Get-FileHash $dest -Algorithm MD5).Hash
            if ($srcHash -eq $destHash) { $shouldCopy = $false }
        }

        if ($shouldCopy) {
            Copy-Item $file.FullName -Destination $dest -Force
            Write-Host "  Copied: $($file.Name)" -ForegroundColor Green
            $copied++
        }
    }
}

Write-Host ""
if ($copied -eq 0) {
    Write-Host "No new reports to push." -ForegroundColor DarkGray
} else {
    Write-Host "$copied file(s) copied." -ForegroundColor Green
}

# Rebuild index.json
$indexPath = "$REPORTS_DEST\index.json"
$reportFiles = @()
foreach ($ext in $EXTENSIONS) {
    $files = Get-ChildItem -Path $REPORTS_DEST -Filter $ext -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $reportFiles += [PSCustomObject]@{
            name     = $f.Name
            modified = $f.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
            size     = $f.Length
        }
    }
}

$reportFiles = $reportFiles | Sort-Object { $_.name } -Descending
$reportFiles | ConvertTo-Json -Depth 3 | Set-Content $indexPath -Encoding UTF8
Write-Host "Updated index.json ($($reportFiles.Count) reports total)" -ForegroundColor Cyan

# Git commit and push
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
