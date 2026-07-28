# ============================================================
#  Deploy Fixed Watchdog to All PCs
#  Updates Watchdog.ps1 with fix for restart spam
#  Requires: Network access to all dispatcher PCs OR manual execution on each PC
# ============================================================

param(
  [string]$SourcePath = "D:\gamewatch\Watchdog.ps1",
  [string[]]$ComputerNames = @(),
  [switch]$LocalOnly = $false
)

Write-Host "=== MicroTyk Watchdog Deployment ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "FIX: Watchdog now correctly detects MicroTyk.ps1" -ForegroundColor Green
Write-Host "     - 30-second restart delay (was 15)" -ForegroundColor Green
Write-Host "     - Alert cooldown: max 1 per 5 minutes" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $SourcePath)) {
  Write-Host "ERROR: Source file not found: $SourcePath" -ForegroundColor Red
  exit 1
}

# Deployment mode
if ($LocalOnly -or $ComputerNames.Count -eq 0) {
  Write-Host "[LOCAL] Copying to local MicroTyk installation..." -ForegroundColor Yellow

  $localPaths = @(
    "D:\gamewatch\Watchdog.ps1",
    "C:\MicroTyk\Watchdog.ps1"
  )

  foreach ($path in $localPaths) {
    $targetDir = Split-Path $path
    if (Test-Path $targetDir) {
      Write-Host "  → $path" -ForegroundColor Green
      Copy-Item $SourcePath $path -Force
    }
  }

  Write-Host ""
  Write-Host "✅ Local Watchdog updated" -ForegroundColor Green
  Write-Host ""
  Write-Host "For remote deployment:" -ForegroundColor Yellow
  Write-Host "  1. Manually RDP/SSH to each PC"
  Write-Host "  2. Copy Watchdog.ps1 from GitHub or share" -ForegroundColor Gray
  Write-Host "  3. Replace D:\gamewatch\Watchdog.ps1 or C:\MicroTyk\Watchdog.ps1" -ForegroundColor Gray
  exit 0
}

# Remote deployment
Write-Host "[REMOTE] Deploying to dispatcher PCs..." -ForegroundColor Yellow
$successCount = 0
$failCount = 0

foreach ($pc in $ComputerNames) {
  Write-Host "  $pc ... " -NoNewline -ForegroundColor Gray

  $targetDir = "\\$pc\C$\MicroTyk"

  if (Test-Path $targetDir) {
    try {
      Copy-Item $SourcePath "$targetDir\Watchdog.ps1" -Force -ErrorAction Stop
      Write-Host "✅ Success" -ForegroundColor Green
      $successCount++
    } catch {
      Write-Host "❌ Failed: $_" -ForegroundColor Red
      $failCount++
    }
  } else {
    Write-Host "❌ Not found (D:\MicroTyk doesn't exist or no access)" -ForegroundColor Red
    $failCount++
  }
}

Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "  Successful: $successCount" -ForegroundColor Green
Write-Host "  Failed:     $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failCount -gt 0) {
  Write-Host "Manual deployment required for failed PCs:" -ForegroundColor Yellow
  Write-Host "  1. RDP to each PC" -ForegroundColor Gray
  Write-Host "  2. Download Watchdog.ps1 from GitHub:" -ForegroundColor Gray
  Write-Host "     https://github.com/vertedasdsa/gamewatch/raw/main/Watchdog.ps1" -ForegroundColor Cyan
  Write-Host "  3. Save to C:\MicroTyk\Watchdog.ps1 (or D:\gamewatch\Watchdog.ps1)" -ForegroundColor Gray
  Write-Host "  4. Restart MicroTyk_Watchdog scheduled task (or wait 2 min for next run)" -ForegroundColor Gray
}
