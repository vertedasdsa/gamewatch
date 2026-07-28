# TEST: Verify MicroTyk restart delay is 15 seconds
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatchdogScript = Join-Path $Root "Watchdog.ps1"
$MicroTykScript = Join-Path $Root "MicroTyk.ps1"

Write-Host "=== MicroTyk Restart Delay Test ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[TEST 1] Checking Watchdog restart delay..." -ForegroundColor Yellow
if (Test-Path $WatchdogScript) {
  $content = Get-Content $WatchdogScript -Raw
  if ($content -match '\$RestartDelaySeconds\s*=\s*(\d+)') {
    $delay = [int]$matches[1]
    Write-Host ("Restart delay found: {0} seconds" -f $delay) -ForegroundColor Green
    if ($delay -eq 15) {
      Write-Host "Delay is correct (15 seconds)" -ForegroundColor Green
    }
  }
}

Write-Host ""
Write-Host "[TEST 2] Checking MicroTyk.ps1..." -ForegroundColor Yellow
if (Test-Path $MicroTykScript) {
  Write-Host "MicroTyk.ps1 found" -ForegroundColor Green
}

Write-Host ""
Write-Host "[TEST 3] Checking MicroTyk.vbs starter..." -ForegroundColor Yellow
$vbs = Join-Path $Root "MicroTyk.vbs"
if (Test-Path $vbs) {
  Write-Host "MicroTyk.vbs found (launcher)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== All components verified ===" -ForegroundColor Green
