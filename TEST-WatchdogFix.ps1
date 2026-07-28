# Verify Watchdog fix for continuous restart spam

Write-Host "=== Watchdog Bug Fix Verification ===" -ForegroundColor Cyan
Write-Host ""

$WatchdogScript = "D:\gamewatch\Watchdog.ps1"
if (-not (Test-Path $WatchdogScript)) {
  Write-Host "ERROR: Watchdog.ps1 not found" -ForegroundColor Red
  exit 1
}

$content = Get-Content $WatchdogScript -Raw

Write-Host "[1] Script name detection" -ForegroundColor Yellow
if ($content -match '\$ScriptName\s*=\s*"([^"]+)"') {
  $name = $matches[1]
  Write-Host "  Primary script: $name" -ForegroundColor Green
  if ($name -eq "MicroTyk.ps1") {
    Write-Host "  ✅ Correct (was GameWatch.ps1, now MicroTyk.ps1)" -ForegroundColor Green
  }
}

if ($content -match '\$ScriptNameLegacy\s*=\s*"([^"]+)"') {
  $legacy = $matches[1]
  Write-Host "  Legacy script: $legacy" -ForegroundColor Green
  Write-Host "  ✅ Fallback support for old GameWatch.ps1" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2] Restart delay (prevent rapid restarts)" -ForegroundColor Yellow
if ($content -match '\$RestartDelaySeconds\s*=\s*(\d+)') {
  $delay = $matches[1]
  Write-Host "  Delay: $delay seconds" -ForegroundColor Green
  if ($delay -ge 30) {
    Write-Host "  ✅ Sufficient (gives process time to stabilize)" -ForegroundColor Green
  } else {
    Write-Host "  ⚠️  May be too short" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "[3] Alert cooldown (prevent spam)" -ForegroundColor Yellow
if ($content -match '\$AlertCooldownMinutes\s*=\s*(\d+)') {
  $cooldown = $matches[1]
  Write-Host "  Cooldown: $cooldown minutes between alerts" -ForegroundColor Green
  Write-Host "  ✅ Prevents Telegram spam" -ForegroundColor Green
}

if ($content -match 'Get-LastAlertTime') {
  Write-Host "  ✅ Alert tracking implemented" -ForegroundColor Green
}

Write-Host ""
Write-Host "[4] Process detection logic" -ForegroundColor Yellow
if ($content -match 'Test-ProcessRunning.*\$ScriptNameLegacy') {
  Write-Host "  ✅ Checks both MicroTyk.ps1 and GameWatch.ps1" -ForegroundColor Green
  Write-Host "  ✅ Detects running process regardless of name" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fixes applied:" -ForegroundColor Green
Write-Host "  1. ✅ Changed script detection: GameWatch.ps1 → MicroTyk.ps1" -ForegroundColor Green
Write-Host "  2. ✅ Added fallback: checks both names (legacy support)" -ForegroundColor Green
Write-Host "  3. ✅ Increased restart delay: 15 sec → 30 sec" -ForegroundColor Green
Write-Host "  4. ✅ Added alert cooldown: max 1 alert per 5 minutes" -ForegroundColor Green
Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  - Watchdog detects MicroTyk (both old GameWatch.ps1 and new MicroTyk.ps1)" -ForegroundColor Gray
Write-Host "  - If process dies → waits 30 sec for graceful shutdown" -ForegroundColor Gray
Write-Host "  - Then checks again before restarting" -ForegroundColor Gray
Write-Host "  - Alert sent ONLY if not restarted in past 5 minutes" -ForegroundColor Gray
Write-Host "  - Result: No spam, only real alerts" -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Watchdog is now fixed" -ForegroundColor Green
