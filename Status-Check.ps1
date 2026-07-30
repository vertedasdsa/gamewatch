# ============================================================
#  GameWatch Status Check
#  Ping all dispatcher PCs and report online/offline status to Telegram
# ============================================================

param(
  [string[]]$ComputerNames = @(),
  [string]$Token = "",
  [string]$ChatId = "",
  [switch]$SaveToFile = $false
)

# Load config if not provided
$cfg = "D:\gamewatch\config.ps1"
if (Test-Path $cfg) {
  . $cfg
}

if (-not $Token -or $Token -like "*YOUR_*") {
  Write-Host "ERROR: Telegram Token not configured in $cfg" -ForegroundColor Red
  Write-Host "Edit the file and add your Token and ChatId" -ForegroundColor Yellow
  exit 1
}

if (-not $ChatId -or $ChatId -like "*YOUR_*") {
  Write-Host "ERROR: Telegram ChatId not configured in $cfg" -ForegroundColor Red
  exit 1
}

# If no computer names provided, use a default list
if ($ComputerNames.Count -eq 0) {
  Write-Host "Enter computer names (comma-separated) or press Enter for saved list:" -ForegroundColor Cyan
  $input = Read-Host "Computers"

  if ($input) {
    $ComputerNames = @($input -split ',' | ForEach-Object { $_.Trim() })
  } else {
    # Try to load from file
    $listFile = "D:\gamewatch\pc-list.txt"
    if (Test-Path $listFile) {
      $ComputerNames = @(Get-Content $listFile | Where-Object { $_ -and -not $_.StartsWith("#") })
      Write-Host "Loaded $($ComputerNames.Count) computers from $listFile" -ForegroundColor Green
    } else {
      Write-Host "ERROR: No computers specified and no pc-list.txt found" -ForegroundColor Red
      exit 1
    }
  }
}

Write-Host ""
Write-Host "Checking status of $($ComputerNames.Count) computers..." -ForegroundColor Cyan
Write-Host ""

$online = @()
$offline = @()
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

foreach ($pc in $ComputerNames) {
  Write-Host "  $pc ... " -NoNewline -ForegroundColor Gray

  if (Test-Connection -ComputerName $pc -Count 1 -Quiet -ErrorAction SilentlyContinue) {
    Write-Host "✅ Online" -ForegroundColor Green
    $online += $pc
  } else {
    Write-Host "❌ Offline" -ForegroundColor Red
    $offline += $pc
  }

  Start-Sleep -Milliseconds 500
}

Write-Host ""

# Build report
$report = @"
📊 GameWatch Status Report
Time: $timestamp

✅ ONLINE ($($online.Count))
$($online | ForEach-Object { "  • $_" } | Join-String -Separator "`n")

❌ OFFLINE ($($offline.Count))
$($offline | ForEach-Object { "  • $_" } | Join-String -Separator "`n")

Total: $($ComputerNames.Count) PCs
"@

Write-Host $report -ForegroundColor Cyan

# Save to file if requested
if ($SaveToFile) {
  $reportFile = "D:\gamewatch\status-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"
  $report | Out-File $reportFile -Encoding UTF8
  Write-Host ""
  Write-Host "Report saved to: $reportFile" -ForegroundColor Yellow
}

# Send to Telegram
Write-Host ""
Write-Host "Sending to Telegram..." -ForegroundColor Yellow

try {
  $tf = Join-Path $env:TEMP "gw_status_$(Get-Date -Format HHmmssfff).txt"
  $Enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($tf, $report, $Enc)

  & curl.exe -s "https://api.telegram.org/bot$Token/sendMessage" `
    --data-urlencode "chat_id=$ChatId" `
    --data-urlencode "text@$tf" | Out-Null

  Remove-Item $tf -ErrorAction SilentlyContinue
  Write-Host "✅ Report sent to Telegram" -ForegroundColor Green
} catch {
  Write-Host "❌ Failed to send to Telegram: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Status Check Complete ===" -ForegroundColor Green
