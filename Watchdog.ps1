# ============================================================
#  Watchdog for MicroTyk (formerly GameWatch)
#  Auto-restart + Telegram alert when main script is stopped
#  Runs every 2 minutes via scheduled task
# ============================================================

# --- SETTINGS ---
$ScriptName = "MicroTyk.ps1"              # Primary script (renamed from GameWatch.ps1)
$ScriptNameLegacy = "GameWatch.ps1"       # Legacy alias (if running old version)
$MainScript = Join-Path $PSScriptRoot $ScriptName
$RestartDelaySeconds = 30        # wait 30 sec before restarting (allow time for graceful shutdown)
$CheckIntervalSeconds = 10       # check every 10 sec if process is alive
$AlertCooldownMinutes = 5        # don't spam alerts: max 1 alert per 5 minutes

$Token   = ""
$ChatId  = ""
$Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$cfg = Join-Path $Root "config.ps1"
if (Test-Path $cfg) { try { . $cfg } catch {} }

# Alert cooldown: prevent spam if script crashes repeatedly
$StateFile = Join-Path $env:TEMP "microtyk_watchdog_state.txt"
function Get-LastAlertTime {
  if (Test-Path $StateFile) {
    try { return [DateTime]::Parse((Get-Content $StateFile)) }
    catch { return [DateTime]::MinValue }
  }
  return [DateTime]::MinValue
}
function Set-LastAlertTime {
  try { [DateTime]::UtcNow.ToString('o') | Out-File $StateFile -Encoding UTF8 } catch {}
}

# --- message icon (red alert) ---
$I_ALERT = [char]::ConvertFromUtf32(0x1F6A8)   # siren - watchdog alert

function Get-UZT { [DateTime]::UtcNow.AddHours(5) }
function Get-Stamp { (Get-UZT).ToString('yyyy-MM-dd HH:mm') }

function Send-Text($text) {
  try {
    $tf = Join-Path $env:TEMP ("gw_w_{0}.txt" -f (Get-Date -Format HHmmssfff))
    $Enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tf, [string]$text, $Enc)
    & curl.exe -s "https://api.telegram.org/bot$Token/sendMessage" --data-urlencode "chat_id=$ChatId" --data-urlencode "text@$tf" | Out-Null
    Remove-Item $tf -ErrorAction SilentlyContinue
  } catch {}
}

function Test-ProcessRunning($scriptName, $scriptNameLegacy) {
  try {
    $procs = Get-Process powershell -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
      try {
        $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId = $($p.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmd -and ($cmd -like "*$scriptName*" -or $cmd -like "*$scriptNameLegacy*")) { return $true }
      } catch {}
    }
  } catch {}
  return $false
}

# Check if main script is running (check both current and legacy name)
if (-not (Test-ProcessRunning $ScriptName $ScriptNameLegacy)) {
  # Main script died - wait a bit then restart it
  Start-Sleep -Seconds $RestartDelaySeconds

  # Double-check it's still not running
  if (-not (Test-ProcessRunning $ScriptName $ScriptNameLegacy)) {
    # Alert user (with cooldown to prevent spam)
    $lastAlert = Get-LastAlertTime
    $timeSinceAlert = [DateTime]::UtcNow - $lastAlert.ToUniversalTime()
    $sendAlert = ($timeSinceAlert.TotalMinutes -ge $AlertCooldownMinutes)

    if ($Token -and $ChatId -and $sendAlert) {
      Send-Text "$I_ALERT MicroTyk was STOPPED on $($env:COMPUTERNAME) (user $env:USERNAME)`nTime: $(Get-Stamp) UZT`nRestarting..."
      Set-LastAlertTime
    }

    # Start the main script via VBS (hide window)
    $vbs = Join-Path $Root "MicroTyk.vbs"
    if (-not (Test-Path $vbs)) { $vbs = Join-Path ([Environment]::GetFolderPath('CommonStartup')) 'MicroTyk.vbs' }
    if (-not (Test-Path $vbs)) { $vbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'MicroTyk.vbs' }

    if (Test-Path $vbs) {
      try { Start-Process wscript.exe -ArgumentList "`"$vbs`"" -ErrorAction SilentlyContinue } catch {}
    } else {
      try { Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -File `"$MainScript`"" -ErrorAction SilentlyContinue } catch {}
    }
  }
}
