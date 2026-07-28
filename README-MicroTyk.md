# MicroTyk — Game Monitoring & Auto-Restart Plugin

**formerly known as GameWatch**

A PowerShell-based tool that monitors game launches on your Windows PC and sends screenshots to Telegram. Includes automatic restart capability when the main process is terminated.

## Quick Start

### Prerequisites
- Windows PowerShell 5.1 or later
- Telegram Bot API token and chat ID
- ffmpeg (for exclusive fullscreen capture — included in installer)

### Installation

#### Option 1: Manual (Development)
```powershell
# 1. Clone the repository
git clone https://github.com/vertedasdsa/gamewatch.git
cd gamewatch

# 2. Create config.ps1 with your Telegram credentials
@"
`$Token = "YOUR_TELEGRAM_BOT_TOKEN"
`$ChatId = "YOUR_CHAT_ID"
`$ExtraGameProcesses = @()  # Optional: add custom game process names
"@ | Out-File "config.ps1" -Encoding UTF8

# 3. Run MicroTyk
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "MicroTyk.ps1"
```

#### Option 2: Scheduled Task (Auto-Start & Watchdog)
```powershell
# Create scheduled task for MicroTyk
$taskName = "MicroTyk"
$taskPath = "\MicroTyk\"
$script = "D:\gamewatch\MicroTyk.ps1"

$action = New-ScheduledTaskAction -Execute powershell.exe `
  -Argument "-NoProfile -WindowStyle Hidden -File '$script'"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
  -Trigger $trigger -Settings $settings -Force

# Create Watchdog task (every 2 minutes)
$watchdogScript = "D:\gamewatch\Watchdog.ps1"
$watchdogAction = New-ScheduledTaskAction -Execute powershell.exe `
  -Argument "-NoProfile -WindowStyle Hidden -File '$watchdogScript'"
$watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 2) `
  -RepetitionDuration ([System.TimeSpan]::MaxValue)

Register-ScheduledTask -TaskName "MicroTyk_Watchdog" -TaskPath $taskPath `
  -Action $watchdogAction -Trigger $watchdogTrigger -Settings $settings -Force
```

## Features

### Main Script (MicroTyk.ps1)
- ✅ Detects game launches from Steam, Epic Games, GOG, EA, Ubisoft, Xbox Game Pass
- ✅ Screenshots all monitors when game starts
- ✅ Periodic screenshots during gameplay (every 15 min)
- ✅ Detects game closure and logs session duration
- ✅ Daily summary report (02:00 UZT)
- ✅ Silent operation (no startup/shutdown messages)
- ✅ Auto-update from GitHub (checks hourly)
- ✅ Single-instance mutex (prevents duplicate runs)

### Watchdog Plugin (Watchdog.ps1)
- ✅ Monitors MicroTyk process health
- ✅ **Auto-restart with 15-second delay** if process dies
- ✅ Telegram alert when restart occurs
- ✅ Runs via scheduled task every 2 minutes
- ✅ Double-verification (checks twice before restarting)

### Configuration (config.ps1)
```powershell
$Token = "YOUR_BOT_TOKEN"           # Required: Telegram bot token
$ChatId = "YOUR_CHAT_ID"            # Required: Your Telegram chat ID
$ExtraGameProcesses = @()           # Optional: Additional game process names
$Active24x7 = $true                 # Optional: Monitor 24/7 (default: true)
$PeriodicScreenshotMin = 15         # Optional: Screenshot interval (min)
$SummaryHourUZT = 2                 # Optional: Daily summary time (UZT)
```

## Testing

### Verify Installation
```powershell
.\TEST-RestartDelay.ps1    # Check Watchdog 15-second timeout
.\TEST-FullRestart.ps1     # Full system verification
```

### Manual Testing
```powershell
# 1. Start MicroTyk in a PowerShell window
.\MicroTyk.ps1

# 2. Launch a game
# → You should receive a screenshot + notification on Telegram

# 3. Test Watchdog restart
# → Stop the PowerShell process (Ctrl+C or close window)
# → Watchdog will detect it within 2 minutes
# → After 15 seconds, MicroTyk restarts automatically
# → You receive a Telegram alert: "MicroTyk was STOPPED on [PC] ... Restarting"
```

## File Structure

```
D:\gamewatch\
├── MicroTyk.ps1              # Main monitoring script (production)
├── Watchdog.ps1              # Auto-restart plugin
├── MicroTyk.vbs              # Hidden launcher (for scheduled task)
├── GameWatch.ps1             # Legacy name (compatibility alias)
├── config.ps1                # Your secrets & overrides (local, not in repo)
├── version.txt               # Current version number
├── sessions.csv              # Game session logs (per-user: %LOCALAPPDATA%\MicroTyk\)
├── TEST-RestartDelay.ps1     # Test: Verify 15-sec restart timeout
├── TEST-FullRestart.ps1      # Test: Full system verification
└── README-MicroTyk.md        # This file
```

## Telegram Notifications

### Game Launch 🎮
```
🎮 GAME LAUNCH on DESKTOP-ABC
User: DESKTOP-ABC\vertedasdsa
App: Cyberpunk2077
Time: 2026-07-28 17:45 UZT
[Screenshot attached]
```

### Game Closed 🔴
```
🔴 GAME CLOSED on DESKTOP-ABC
User: DESKTOP-ABC\vertedasdsa
App: Cyberpunk2077
Played: 120 min
Time: 2026-07-28 20:45 UZT
```

### Watchdog Alert 🚨
```
🚨 MicroTyk was STOPPED on DESKTOP-ABC (user vertedasdsa)
Time: 2026-07-28 20:46 UZT
Restarting...
```

### Daily Summary 📊
```
📊 DAILY SUMMARY 2026-07-28 on DESKTOP-ABC
Total: 4h 35m
  Cyberpunk2077: 180 min (1 sessions)
  GTA5: 95 min (2 sessions)
  VALORANT-Win64-Shipping: 80 min (3 sessions)
```

## Auto-Update Mechanism

MicroTyk checks for updates every 60 minutes:
1. Fetches `version.txt` from GitHub
2. Compares with local `$ScriptVersion`
3. If newer version found:
   - Downloads `MicroTyk.ps1` from GitHub
   - Validates syntax & file size
   - Replaces local script
   - Restarts (if not in-game)
   - Sends update notification

**Never interrupts active game session.**

## Troubleshooting

### "Access Denied" when creating scheduled task
```powershell
# Run PowerShell as Administrator
Start-Process powershell -Verb RunAs
```

### Defender/AMSI blocking the script
```powershell
# Add process exclusion (run as Admin)
Add-MpPreference -ExclusionProcess 'powershell.exe','wscript.exe'
```

### No screenshot captured (appears blank)
- Check if game uses exclusive fullscreen
- Ensure ffmpeg.exe is present in `D:\gamewatch\`
- Check Telegram chat ID is correct

### Watchdog not restarting MicroTyk
- Verify scheduled task "MicroTyk_Watchdog" exists
- Check Task Scheduler history for errors
- Ensure config.ps1 has Telegram credentials

## GitHub Repository

- **Repo:** https://github.com/vertedasdsa/gamewatch
- **Public:** Yes (secrets stored in local config.ps1, not in repo)
- **Update Source:** https://raw.githubusercontent.com/vertedasdsa/gamewatch/main

## Version History

- **v13** (2026-07-23): Silent startup, added timestamps to all alerts
- **v13+** (2026-07-28): Renamed to MicroTyk, added Watchdog with 15-sec restart delay

## License

Personal tool — use at your own discretion.

## Author

Created for transparent personal use on own PC (not stealth monitoring).
