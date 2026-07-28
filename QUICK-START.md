# MicroTyk Quick Start Checklist

## 🔧 Setup (5 minutes)

### 1. Get Telegram Bot Token
- [ ] Go to Telegram → Search **@BotFather**
- [ ] Send `/newbot`
- [ ] Name: "MicroTyk" (anything)
- [ ] Username: "microtyk_dispatcher_bot" (must be unique)
- [ ] **Copy the token** (save it)

### 2. Get Your Chat ID
- [ ] Search your new bot in Telegram (@microtyk_dispatcher_bot)
- [ ] Click **Start** → Send any message
- [ ] Visit: `https://api.telegram.org/bot{PASTE_TOKEN}/getUpdates`
- [ ] Find: `"chat":{"id":123456789}` → That's your **Chat ID**

### 3. Configure MicroTyk
- [ ] Edit `D:\gamewatch\config.ps1`:
  ```powershell
  $Token = "PASTE_YOUR_TOKEN_HERE"
  $ChatId = "PASTE_YOUR_CHAT_ID_HERE"
  ```
- [ ] Save file

### 4. Test Telegram Connection
```powershell
powershell -ExecutionPolicy Bypass -File "D:\gamewatch\TEST-Telegram.ps1"
# Should output: ✅ All tests passed!
# Check Telegram for test message
```

### 5. Start MicroTyk
```powershell
powershell -NoProfile -WindowStyle Hidden -File "D:\gamewatch\MicroTyk.ps1"
# Or: cscript.exe "D:\gamewatch\MicroTyk.vbs"
```

### 6. Test with a Game
- [ ] Launch any game (Steam, Epic, GOG, etc.)
- [ ] Wait 20 seconds
- [ ] **Check Telegram** for screenshot 🎮
- [ ] Game close → Final screenshot 🔴

---

## ✅ Verify Setup

```powershell
# 1. MicroTyk running?
Get-Process powershell | Where-Object { $_.CommandLine -like "*MicroTyk*" }
# Should show: MicroTyk process

# 2. Config correct?
Get-Content "D:\gamewatch\config.ps1" | Select-String "Token|ChatId"
# Should show: $Token = "123456:ABC..." AND $ChatId = "123456789"

# 3. Sessions logged?
Get-ChildItem "$env:LOCALAPPDATA\MicroTyk\"
# Should show: sessions.csv
```

---

## 🚀 Auto-Start (Optional)

### Create Scheduled Task
```powershell
# MicroTyk startup task
$action = New-ScheduledTaskAction -Execute powershell.exe `
  -Argument "-NoProfile -WindowStyle Hidden -File D:\gamewatch\MicroTyk.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "MicroTyk" -Action $action -Trigger $trigger -Force

# Watchdog restart task (every 2 min)
$watchdogAction = New-ScheduledTaskAction -Execute powershell.exe `
  -Argument "-NoProfile -WindowStyle Hidden -File D:\gamewatch\Watchdog.ps1"
$watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 2) `
  -RepetitionDuration ([System.TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName "MicroTyk_Watchdog" -Action $watchdogAction -Trigger $watchdogTrigger -Force
```

---

## 📊 What You Get

| Event | Telegram Message | Screenshot |
|-------|------------------|-----------|
| Game Launch | 🎮 GAME LAUNCH | ✅ Yes (fullscreen) |
| Playing (every 20 min) | 🔄 GAME (playing 20 min) | ✅ Yes |
| Game Closes | 🔴 GAME CLOSED (played 120 min) | ✅ Yes |
| Daily Summary | 📊 DAILY SUMMARY (2:00 UZT) | ❌ No (text only) |
| Watchdog Restart | 🚨 MicroTyk was STOPPED ... Restarting | ❌ No (max 1 per 5 min) |

---

## 🔧 Configuration Options

Edit `D:\gamewatch\config.ps1` to customize:

```powershell
# Add custom game executables
$ExtraGameProcesses = @("MyGame.exe", "CustomGame.exe")

# Change screenshot interval (default: 20 min)
$PeriodicScreenshotMin = 30

# Monitor only during work hours (default: 24/7)
$Active24x7 = $false
$ActiveStartUZT = 9      # 09:00 UZT
$ActiveEndUZT = 18       # 18:00 UZT

# Change daily summary time (default: 02:00 UZT)
$SummaryHourUZT = 5
```

---

## ⚠️ Troubleshooting

### "No screenshots in Telegram"
1. Check `config.ps1` has real Token and ChatId (not "YOUR_...")
2. Run `TEST-Telegram.ps1` to verify connection
3. Check MicroTyk is running: `Get-Process powershell | grep MicroTyk`
4. Launch a game, wait 20 seconds, check Telegram
5. Check logs: `cat "$env:LOCALAPPDATA\MicroTyk\sessions.csv"`

### "Too many restart alerts"
- Already fixed! Should be max 1 alert per 5 minutes
- If still spamming, check `Watchdog.ps1` has `$AlertCooldownMinutes = 5`

### "MicroTyk crashes constantly"
- Check Defender isn't blocking it
- Run from Administrator shell
- Check logs in `$env:LOCALAPPDATA\MicroTyk\`

---

## 📚 Files

| File | Purpose |
|------|---------|
| `MicroTyk.ps1` | Main game monitoring script |
| `Watchdog.ps1` | Auto-restart when process dies |
| `MicroTyk.vbs` | Hidden launcher (no window flicker) |
| `config.ps1` | **Your secrets: Token + ChatId** ⚠️ |
| `sessions.csv` | Game session logs (in %LOCALAPPDATA%\MicroTyk\) |

---

## 🔐 Security

- ✅ **config.ps1 is NOT in GitHub** (in .gitignore)
- ✅ Token is safe locally
- ✅ ChatId is just your Telegram ID (safe to share)
- ⚠️ If token leaks → Go to BotFather, delete bot, create new one

---

**Status:** Ready to go! 🚀  
**Questions?** Check: `SETUP-Telegram.md` or `README-MicroTyk.md`
