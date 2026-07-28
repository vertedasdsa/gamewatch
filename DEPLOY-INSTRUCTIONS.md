# MicroTyk Watchdog Deployment Instructions

## 🔴 Problem Fixed
Watchdog was detecting `GameWatch.ps1` instead of `MicroTyk.ps1`, causing **continuous restart spam every 2 minutes**.

## ✅ Solution
Updated Watchdog.ps1 with:
1. **Correct script name detection**: MicroTyk.ps1 (primary) + GameWatch.ps1 (legacy)
2. **Longer restart delay**: 15 sec → 30 sec
3. **Alert cooldown**: Max 1 alert per 5 minutes (stops spam)

---

## Deployment Options

### Option 1: Local PC Only (Quick Test)
```powershell
powershell -ExecutionPolicy Bypass -File "D:\gamewatch\DEPLOY-Watchdog-All-PCs.ps1" -LocalOnly
```

### Option 2: Manual Deployment (Each PC Individually)

**On Each Dispatcher PC:**

1. Download updated Watchdog:
```powershell
# Method A: From GitHub (requires internet)
$url = "https://raw.githubusercontent.com/vertedasdsa/gamewatch/main/Watchdog.ps1"
Invoke-WebRequest -Uri $url -OutFile "C:\MicroTyk\Watchdog.ps1"

# Method B: Copy from share/USB
Copy-Item "\\YOUR-SERVER\share\Watchdog.ps1" "C:\MicroTyk\Watchdog.ps1" -Force
```

2. Verify update:
```powershell
Get-Content "C:\MicroTyk\Watchdog.ps1" | Select-String "MicroTyk.ps1"
# Should output: $ScriptName = "MicroTyk.ps1"
```

3. Restart Watchdog task:
```powershell
# Option A: Stop and let it auto-restart
Stop-Process -Name powershell -Force  # Kills Watchdog

# Option B: Via Task Scheduler
Get-ScheduledTask -TaskName "MicroTyk_Watchdog" | Start-ScheduledTask
```

### Option 3: Network Deployment (All PCs at Once)

**Requires:** Admin access to network share or RDP coordination

```powershell
# List of dispatcher PCs to update
$pcs = @(
  "DESKTOP-4CV6-6",
  "DESKTOP-1QN6FMS",
  "DESKTOP-PHMBF4Q",
  "DESKTOP-3RTP698",
  "ADMIN"
)

powershell -ExecutionPolicy Bypass `
  -File "D:\gamewatch\DEPLOY-Watchdog-All-PCs.ps1" `
  -ComputerNames $pcs
```

---

## Verification

### On Each PC
```powershell
# Check Watchdog is running
Get-Process powershell | Where-Object { $_.CommandLine -like "*Watchdog*" }

# Check configuration
Get-Content "C:\MicroTyk\Watchdog.ps1" | Select-String -Pattern '$ScriptName|$RestartDelaySeconds|$AlertCooldownMinutes'

# Should output:
# $ScriptName = "MicroTyk.ps1"
# $RestartDelaySeconds = 30
# $AlertCooldownMinutes = 5
```

### Verify Fix Works
1. **Stop MicroTyk process** manually (kill powershell)
2. **Wait 30 seconds** (new delay)
3. **Check Telegram** — should receive 🚨 alert ONCE (not spamming)
4. **MicroTyk should restart automatically**
5. **Wait 5 minutes** — no new alerts (cooldown working)

---

## Rollback (If Issues)

```powershell
# Restore from GitHub (old version) or backup
$url = "https://raw.githubusercontent.com/vertedasdsa/gamewatch/cc03168/Watchdog.ps1"  # Old commit
Invoke-WebRequest -Uri $url -OutFile "C:\MicroTyk\Watchdog.ps1"
```

---

## Checklist

- [ ] Watchdog.ps1 updated on all PCs
- [ ] Verified script name: MicroTyk.ps1 (main), GameWatch.ps1 (legacy)
- [ ] Confirmed restart delay: 30 seconds
- [ ] Confirmed alert cooldown: 5 minutes
- [ ] No more restart spam in Telegram (max 1 alert per 5 min)
- [ ] MicroTyk auto-restarts when process dies

---

## Files Involved

| File | Location | Purpose |
|------|----------|---------|
| `MicroTyk.ps1` | `D:\gamewatch\` / `C:\MicroTyk\` | Main game monitoring script |
| `Watchdog.ps1` | `D:\gamewatch\` / `C:\MicroTyk\` | **UPDATED** Auto-restart plugin |
| `MicroTyk.vbs` | `D:\gamewatch\` / Common Startup | Hidden launcher |
| `config.ps1` | `D:\gamewatch\` / `C:\MicroTyk\` | Local secrets (Token, ChatId) |

---

## Support

If Telegram still shows restart spam after update:
1. Verify Watchdog.ps1 contains `$ScriptName = "MicroTyk.ps1"`
2. Verify MicroTyk.ps1 is actually running (not crashing)
3. Check Windows Task Scheduler — is `MicroTyk_Watchdog` scheduled correctly?
4. Increase `$RestartDelaySeconds` if process needs more time to stabilize

---

**Deployment Date:** 2026-07-28  
**Status:** Ready for all PCs  
**GitHub:** https://github.com/vertedasdsa/gamewatch
