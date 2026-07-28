# MicroTyk Telegram Setup Guide

## Step 1: Create Telegram Bot

1. **Open Telegram** → Search for **@BotFather**
2. Send `/newbot`
3. Follow prompts:
   - Bot name: "MicroTyk" (or your name)
   - Bot username: "microtyk_dispatcher_bot" (must be unique, ends with `_bot`)
4. **Copy the token** (looks like: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

## Step 2: Get Your Chat ID

### Option A: Private Message to Bot
1. Search for your new bot in Telegram (e.g. @microtyk_dispatcher_bot)
2. Click **Start**
3. Send any message
4. Go to: `https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates`
5. Replace `{YOUR_TOKEN}` with your bot token from Step 1
6. Find `"chat":{"id":123456789...}` — that's your **Chat ID**

### Option B: Using @userinfobot
1. Search for **@userinfobot**
2. Click **Start**
3. It will show you your **User ID** (this is your Chat ID)

### Option C: Group Chat
If you want screenshots in a group chat:
1. Create a Telegram group (e.g. "Dispatcher MicroTyk Logs")
2. Add your bot to the group (needs admin)
3. Send a message in group
4. Check `getUpdates` API — Chat ID will be negative (e.g. `-123456789`)

## Step 3: Configure MicroTyk

**Edit file:** `D:\gamewatch\config.ps1`

```powershell
$Token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"   # Your bot token from BotFather
$ChatId = "6083023650"                                   # Your Chat ID from @userinfobot
```

## Step 4: Start MicroTyk

```powershell
# Start in hidden window
powershell -NoProfile -WindowStyle Hidden -File "D:\gamewatch\MicroTyk.ps1"

# Or with VBS starter (no window flicker)
cscript.exe "D:\gamewatch\MicroTyk.vbs"
```

## Step 5: Test

1. **Launch a game** (Steam, Epic, GOG, etc.)
2. **Wait 20 seconds** for fullscreen detection
3. **Check Telegram** — you should receive a screenshot 🎮

Example message:
```
🎮 GAME LAUNCH on DESKTOP-ABC
User: DESKTOP-ABC\vertttt
App: Cyberpunk2077
Time: 2026-07-28 17:45 UZT
[Screenshot attached]
```

## Troubleshooting

### No screenshots arriving?

1. **Check config.ps1:**
   ```powershell
   Get-Content D:\gamewatch\config.ps1
   # Should show your real Token and ChatId (not "YOUR_...")
   ```

2. **Verify bot token works:**
   ```powershell
   $token = "YOUR_TOKEN_HERE"
   Invoke-WebRequest "https://api.telegram.org/bot$token/getMe"
   # Should return bot info, not "Unauthorized"
   ```

3. **Check Chat ID:**
   ```powershell
   $token = "YOUR_TOKEN_HERE"
   $chatId = "YOUR_CHAT_ID_HERE"
   $msg = "Test message"
   Invoke-WebRequest "https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=$msg"
   # Should succeed (check Telegram)
   ```

4. **Verify MicroTyk is running:**
   ```powershell
   Get-Process powershell | Where-Object { $_.CommandLine -like "*MicroTyk*" }
   # Should show a process
   ```

5. **Check logs:**
   ```powershell
   Get-Content "$env:LOCALAPPDATA\MicroTyk\sessions.csv"
   # Should show game sessions
   ```

## Telegram Bot Commands (Optional)

You can add commands to your bot in **BotFather**:

- `/start` — Welcome message
- `/help` — Help
- `/stats` — Session statistics

(MicroTyk doesn't respond to these, they're just for users)

## Security Notes

- ⚠️ **Never commit config.ps1 to GitHub** (it's in .gitignore)
- ✅ Token is safe in local `config.ps1` (not in public repo)
- ✅ If token leaks, delete bot in BotFather and create new one
- ✅ Chat ID in Telegram messages is your user/group ID (safe to share)

## Next Steps

- Set up scheduled task for auto-start: `MicroTyk` (at login)
- Set up Watchdog: `MicroTyk_Watchdog` (every 2 min, auto-restart)
- See: `README-MicroTyk.md` and `DEPLOY-INSTRUCTIONS.md`
