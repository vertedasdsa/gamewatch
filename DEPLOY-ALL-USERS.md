# Deploy MicroTyk to All Dispatcher PCs

## 🚀 Three Deployment Methods

### Method 1: Automatic (Network Deploy) ⭐ FASTEST

**From your admin PC:**

```powershell
cd D:\gamewatch

# 1. Test deployment (no changes)
powershell -ExecutionPolicy Bypass -File "Deploy-To-All-PCs.ps1" -TestOnly

# 2. Deploy for real
powershell -ExecutionPolicy Bypass -File "Deploy-To-All-PCs.ps1" `
  -ComputerNames @("DESKTOP-1QN6FMS", "ADMIN", "DESKTOP-ABC", ...)
```

**What it does:**
1. ✅ Copies MicroTyk to each PC (`C:\MicroTyk-Install`)
2. ✅ Runs Install-MicroTyk.ps1 automatically
3. ✅ Creates scheduled tasks
4. ✅ Starts MicroTyk

**Requirements:**
- Admin rights on source PC
- Network access to all target PCs (\\PC\C$)
- PowerShell Remoting enabled (or enable with: `Enable-PSRemoting -Force`)

---

### Method 2: Manual per PC (Most Reliable)

**On each dispatcher PC (as Administrator):**

```powershell
# Download from GitHub
$url = "https://raw.githubusercontent.com/vertedasdsa/gamewatch/main/Install-MicroTyk.ps1"
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\Install-MicroTyk.ps1"

# Run installer
powershell -ExecutionPolicy Bypass -File "$env:TEMP\Install-MicroTyk.ps1"
```

Or from shared drive:
```powershell
powershell -ExecutionPolicy Bypass -File "\\YOUR-SERVER\share\Install-MicroTyk.ps1"
```

---

### Method 3: Group Policy (Enterprise)

**Requirements:** AD + Group Policy capability

1. Create shared folder: `\\DOMAIN\SYSVOL\MicroTyk\`
2. Copy all files there
3. Create Group Policy:
   - Scope: Organizational Unit with dispatcher PCs
   - Type: Startup Script
   - Script: `Install-MicroTyk.ps1`
4. Update Group Policy on all PCs

---

## 📋 Before You Deploy

### 1. Get Telegram Credentials

```powershell
# Or skip and let users configure manually
$Token = "YOUR_BOT_TOKEN"
$ChatId = "YOUR_CHAT_ID"
```

### 2. List All Dispatcher PCs

```powershell
# Test connectivity to all PCs
$pcs = @("DESKTOP-1QN6FMS", "DESKTOP-ABC", "ADMIN", "PCBAXT", ...)
foreach ($pc in $pcs) {
  if (Test-Connection -ComputerName $pc -Count 1 -Quiet) {
    Write-Host "✅ $pc" -ForegroundColor Green
  } else {
    Write-Host "❌ $pc (offline)" -ForegroundColor Red
  }
}
```

---

## 🔧 Detailed: Method 1 (Network Deploy)

### Step 1: Source Files Ready
```powershell
cd D:\gamewatch
ls Install-MicroTyk.ps1  # Should exist
ls Deploy-To-All-PCs.ps1  # Should exist
```

### Step 2: Test Connectivity
```powershell
$pcs = @("DESKTOP-1QN6FMS", "DESKTOP-ABC", "ADMIN")

foreach ($pc in $pcs) {
  if (Test-Connection -ComputerName $pc -Count 1 -Quiet) {
    Write-Host "✅ $pc reachable" -ForegroundColor Green
  } else {
    Write-Host "❌ $pc offline" -ForegroundColor Red
  }
}
```

### Step 3: Enable PowerShell Remoting (if needed)
```powershell
# On source PC (where you're running Deploy-To-All-PCs.ps1)
Enable-PSRemoting -Force

# On target PCs (if not domain-joined)
# Manual RDP: powershell -NoProfile -Command "Enable-PSRemoting -Force"
```

### Step 4: Test Deployment (DRY RUN)
```powershell
powershell -ExecutionPolicy Bypass -File "D:\gamewatch\Deploy-To-All-PCs.ps1" `
  -ComputerNames @("DESKTOP-ABC") `
  -TestOnly
# Should show: ✅ Reachable (test mode)
```

### Step 5: Full Deployment
```powershell
powershell -ExecutionPolicy Bypass -File "D:\gamewatch\Deploy-To-All-PCs.ps1" `
  -ComputerNames @("DESKTOP-1QN6FMS", "ADMIN", "PCBAXT", "DESKTOP-ABC", ...)
```

**Wait ~2-3 seconds per PC for installation**

### Step 6: Verify
```powershell
# Check if MicroTyk running on each PC
foreach ($pc in $pcs) {
  Get-Process powershell -ComputerName $pc -ErrorAction SilentlyContinue | `
    Where-Object { $_.CommandLine -like "*MicroTyk*" } | `
    Select-Object @{N="PC";E={$pc}}, ProcessName, Id
}
```

---

## ✅ Post-Deployment Checklist

- [ ] All PCs deployed successfully
- [ ] No errors in Deploy-To-All-PCs output
- [ ] Scheduled tasks created:
  - `MicroTyk` (at login)
  - `MicroTyk_Watchdog` (every 2 min)
- [ ] Test on 1 PC: Launch game → Check Telegram for screenshot
- [ ] Check each PC has `C:\MicroTyk\config.ps1` with Token + ChatId
- [ ] Defender exclusions added (powershell.exe, C:\MicroTyk)
- [ ] Watchdog restart working (kill MicroTyk, wait 30s for auto-restart)

---

## 🔐 Configuration (Telegram Credentials)

### Option A: Pre-Configure (Recommended)
```powershell
# Modify Deploy-To-All-PCs.ps1 before running:
$Token = "YOUR_BOT_TOKEN"
$ChatId = "YOUR_CHAT_ID"

# Installer will use these automatically
```

### Option B: Manual per PC
```powershell
# Edit C:\MicroTyk\config.ps1 on each PC:
$Token = "YOUR_BOT_TOKEN"
$ChatId = "YOUR_CHAT_ID"

# Restart MicroTyk to apply
Stop-Process -Name powershell -Filter "*MicroTyk*" -Force
Start-Sleep 2
& "C:\MicroTyk\MicroTyk.vbs"
```

---

## ⚠️ Troubleshooting

### "Connection refused" on some PCs
- PC is offline → Wait and retry
- Firewall blocks \\PC\C$ → Configure Windows Firewall
- Not in same domain → Try RDP instead

### "PowerShell Remoting not enabled"
```powershell
# Enable on each PC (or via Group Policy)
Enable-PSRemoting -Force
```

### "Access denied" to C$
- Need admin on target PC
- Or push via shared network drive instead

### Installation failed on some PCs
```powershell
# Manually deploy to failed PCs:
# 1. RDP to PC as admin
# 2. Run:
powershell -ExecutionPolicy Bypass -File "C:\MicroTyk-Install\Install-MicroTyk.ps1"
```

---

## 📊 What Gets Installed

| File | Location | Purpose |
|------|----------|---------|
| MicroTyk.ps1 | C:\MicroTyk\ | Main script |
| Watchdog.ps1 | C:\MicroTyk\ | Auto-restart |
| MicroTyk.vbs | C:\MicroTyk\ + Common Startup | Launcher |
| config.ps1 | C:\MicroTyk\ | Telegram config |
| sessions.csv | %LOCALAPPDATA%\MicroTyk\ | Game logs |

### Scheduled Tasks Created
```
MicroTyk              → Runs at user login
MicroTyk_Watchdog     → Runs every 2 minutes
```

### Defender Exclusions Added
```
Process: powershell.exe, wscript.exe
Path: C:\MicroTyk\
```

---

## 🚀 After Deployment

### Immediate
- MicroTyk starts when users log in
- Watchdog monitors in background

### On First Game Launch
- Screenshot sent to Telegram (if config.ps1 has Token + ChatId)
- Session logged to C:\%LOCALAPPDATA%\MicroTyk\sessions.csv

### Daily at 02:00 UZT
- Summary report in Telegram
- All sessions for that day

---

## 📞 Support

If any PC fails deployment:
1. Check network connectivity: `ping PC-NAME`
2. Check admin access: `dir \\PC-NAME\C$`
3. Check PowerShell Remoting: `Test-PSRemoting -ComputerName PC-NAME`
4. Fall back to Method 2 (Manual RDP)

---

**Status:** Ready for deployment! 🚀  
**GitHub:** https://github.com/vertedasdsa/gamewatch
