# ============================================================
#  Deploy MicroTyk to All Dispatcher PCs
#  Prerequisites:
#  - Network access to all PCs (via \\PC\C$)
#  - OR: RDP/SSH access to each PC
#  - Admin rights on source machine
# ============================================================

param(
  [string[]]$ComputerNames = @(),
  [string]$SourcePath = "D:\gamewatch",
  [string]$Token = "",
  [string]$ChatId = "",
  [switch]$TestOnly = $false
)

Write-Host "=== MicroTyk Mass Deployment ===" -ForegroundColor Cyan
Write-Host ""

# If no computer names provided, discover from Active Directory
if ($ComputerNames.Count -eq 0) {
  Write-Host "No computer names provided. Options:" -ForegroundColor Yellow
  Write-Host "  1. Run with -ComputerNames @('PC1', 'PC2', ...)" -ForegroundColor Gray
  Write-Host "  2. Enter computer names when prompted" -ForegroundColor Gray
  Write-Host "  3. Example:" -ForegroundColor Gray
  Write-Host "     .\Deploy-To-All-PCs.ps1 -ComputerNames @('DESKTOP-ABC', 'ADMIN')" -ForegroundColor Cyan
  Write-Host ""

  Write-Host "Enter computer names (comma-separated) or 'quit' to exit:" -ForegroundColor Cyan
  $input = Read-Host "Computers"

  if ($input -eq "quit") { exit }
  $ComputerNames = @($input -split ',' | ForEach-Object { $_.Trim() })
}

Write-Host "Deployment config:" -ForegroundColor Yellow
Write-Host "  Source:       $SourcePath" -ForegroundColor Gray
Write-Host "  Computers:    $($ComputerNames -join ', ')" -ForegroundColor Gray
Write-Host "  Test mode:    $TestOnly" -ForegroundColor Gray
Write-Host ""

if ($TestOnly) {
  Write-Host "⚠️  TEST MODE - Not actually deploying" -ForegroundColor Yellow
}

Write-Host ""

# Validate source
if (-not (Test-Path "$SourcePath\Install-MicroTyk.ps1")) {
  Write-Host "ERROR: Install-MicroTyk.ps1 not found at $SourcePath" -ForegroundColor Red
  exit 1
}

Write-Host "Step 1: Copying files to network share..." -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failCount = 0
$skipCount = 0

foreach ($pc in $ComputerNames) {
  Write-Host "  $pc ... " -NoNewline -ForegroundColor Gray

  # Test connectivity
  if (-not (Test-Connection -ComputerName $pc -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Unreachable" -ForegroundColor Red
    $failCount++
    continue
  }

  # Map network path
  $targetPath = "\\$pc\C$\MicroTyk-Install"

  if ($TestOnly) {
    Write-Host "✅ Reachable (test mode)" -ForegroundColor Yellow
    $skipCount++
    continue
  }

  # Copy files
  try {
    if (Test-Path $targetPath) {
      Remove-Item $targetPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $targetPath -Force -ErrorAction Stop | Out-Null
    Copy-Item "$SourcePath\*" $targetPath -Force -ErrorAction Stop -Exclude ".git*"

    Write-Host "✅ Files copied" -ForegroundColor Green
    $successCount++
  } catch {
    Write-Host "❌ Copy failed: $($_.Exception.Message)" -ForegroundColor Red
    $failCount++
  }
}

Write-Host ""
Write-Host "Step 2: Running installer on each PC..." -ForegroundColor Cyan
Write-Host ""

foreach ($pc in $ComputerNames) {
  Write-Host "  $pc ... " -NoNewline -ForegroundColor Gray

  if ($TestOnly) {
    Write-Host "⏭️  (test mode)" -ForegroundColor Yellow
    continue
  }

  try {
    $session = New-PSSession -ComputerName $pc -ErrorAction Stop

    $installScript = @"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
& "C:\MicroTyk-Install\Install-MicroTyk.ps1" -NoStart
"@

    Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($installScript)) -ErrorAction Stop | Out-Null
    Remove-PSSession -Session $session

    Write-Host "✅ Installed" -ForegroundColor Green
  } catch {
    Write-Host "❌ Install failed: $($_.Exception.Message.Substring(0, 30))..." -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "  Successful: $successCount" -ForegroundColor Green
Write-Host "  Failed:     $failCount" -ForegroundColor Red
Write-Host "  Tested:     $skipCount" -ForegroundColor Yellow
Write-Host ""

if ($TestOnly) {
  Write-Host "TEST MODE COMPLETE" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "To deploy for real, run:" -ForegroundColor Cyan
  Write-Host "  .\Deploy-To-All-PCs.ps1 -ComputerNames @($($ComputerNames | ForEach-Object { "`'$_`'" } | Join-String -Separator ', '))" -ForegroundColor Gray
} else {
  Write-Host "Deployment complete. MicroTyk will start on next login." -ForegroundColor Green
  Write-Host ""
  Write-Host "If any failed, manually deploy to those PCs:" -ForegroundColor Yellow
  Write-Host "  1. RDP to PC" -ForegroundColor Gray
  Write-Host "  2. powershell -NoProfile -ExecutionPolicy Bypass" -ForegroundColor Gray
  Write-Host "  3. & C:\MicroTyk-Install\Install-MicroTyk.ps1" -ForegroundColor Gray
}
