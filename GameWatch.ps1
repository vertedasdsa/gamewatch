# ============================================================
#  GameWatch v4 (portable) - game monitoring on own PC
#  Paths are relative to this script's folder ($PSScriptRoot).
#  Steam libraries are auto-detected on each machine.
# ============================================================

# --- SETTINGS ---
$ScriptVersion = 11               # bump on each release; auto-update compares this to version.txt in the repo
$UpdateBaseUrl = "https://raw.githubusercontent.com/vertedasdsa/gamewatch/main"   # central update source (auto-update ON)
$UpdateCheckMin = 60              # how often to check the repo for a newer version (minutes)
$Token   = ""                     # secrets live in local config.ps1 (installer writes it) - NOT in the public repo
$ChatId  = ""
$PollSeconds           = 4
$CaptureDelaySeconds   = 20
$FullscreenWaitMax     = 60
$PeriodicScreenshotMin = 15
$Active24x7     = $true           # $true = monitor 24/7 (no time limit). Set $false to use the window below.
$ActiveStartUZT = 17
$ActiveEndUZT   = 4
$SummaryHourUZT = 2

$Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
# load local secrets / optional overrides (token, chat id, watch window, extra games) - kept OUT of the repo
$cfg = Join-Path $Root "config.ps1"
if (Test-Path $cfg) { try { . $cfg } catch {} }
$FFmpeg = Join-Path $Root "ffmpeg.exe"
# per-user data (each Windows user keeps own log/state -> no conflicts between sessions)
$Data = Join-Path $env:LOCALAPPDATA "GameWatch"
try { New-Item -ItemType Directory -Force $Data | Out-Null } catch {}
$LogFile   = Join-Path $Data "sessions.csv"
$StateFile = Join-Path $Data "state.txt"

# --- message icons (built from unicode codepoints so this script file stays pure ASCII) ---
$Enc     = New-Object System.Text.UTF8Encoding($false)
$I_INFO  = [char]::ConvertFromUtf32(0x1F7E2)   # green circle - info / started on a device
$I_GAME  = [char]::ConvertFromUtf32(0x1F3AE)   # controller   - game launch
$I_SHOT  = [char]::ConvertFromUtf32(0x1F4F8)   # camera       - fullscreen screenshot
$I_LOOP  = [char]::ConvertFromUtf32(0x1F504)   # arrows       - periodic screenshot
$I_STOP  = [char]::ConvertFromUtf32(0x1F534)   # red circle   - game closed
$I_SUM   = [char]::ConvertFromUtf32(0x1F4CA)   # bar chart    - daily summary

$GameProcesses = @("MK12","VALORANT-Win64-Shipping","valorant","cs2","GTA5","RDR2","eldenring",
                   "Cyberpunk2077","FortniteClient-Win64-Shipping","LeagueClient","dota2","Overwatch")
$NonGames = @("explorer","chrome","firefox","msedge","opera","brave","vlc","mpc-hc64","mpc-hc",
              "claude","Code","Telegram","obs64","obs32","mstsc","zoom","wmplayer","POWERPNT",
              "SnippingTool","ScreenSketch","ScreenClippingHost","ShareX","Greenshot","Lightshot","Snagit32","SnagitEditor",
              "wallpaper32","wallpaper64","wallpaperservice32_c","wallpaperservice64_c",
              # launchers (not games themselves)
              "EpicGamesLauncher","EpicWebHelper","EpicOnlineServicesUIHelper",
              "GalaxyClient","GalaxyClientService","EADesktop","EABackgroundService","Origin","OriginWebHelperService",
              "UbisoftConnect","upc","UplayWebCore","Battle.net","RiotClientServices","RiotClientUx","RiotClientUxRender",
              # engines / dev tools (excluded so real work is not flagged as a game)
              "UnrealEditor","UnrealEditor-Cmd","UE4Editor","UnrealEditor-Win64-DebugGame","CrashReportClient",
              "QuixelBridge","blender","3dsmax","maya")
$SteamExcludeDirs = @("wallpaper_engine","OBS Studio","Steamworks Shared","SteamVR")

# --- auto-detect game install dirs (Steam, Epic, Xbox, GOG, EA, Ubisoft) ---
$GameDirs = @()
# Steam libraries (steamapps\common)
try {
  $sp = $null
  foreach ($k in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
    try { $pp = Get-ItemProperty $k -ErrorAction Stop; if ($pp.SteamPath) { $sp = $pp.SteamPath }; if ($pp.InstallPath) { $sp = $pp.InstallPath } } catch {}
  }
  if ($sp) {
    $sp = $sp -replace '/','\'
    $libs = @($sp)
    $vdf = Join-Path $sp 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) { $libs += (Select-String -Path $vdf -Pattern '"path"\s*"([^"]+)"' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value -replace '\\\\','\' }) }
    foreach ($l in ($libs | Select-Object -Unique)) { $c = Join-Path $l 'steamapps\common'; if (Test-Path $c) { $GameDirs += $c } }
  }
} catch {}
# Epic Games - ONLY entries categorized as 'games' (excludes Unreal Engine / Quixel / Fab / editor tools)
try {
  $man = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path $man) {
    foreach ($it in (Get-ChildItem $man -Filter *.item -ErrorAction SilentlyContinue)) {
      try { $j = Get-Content $it.FullName -Raw | ConvertFrom-Json
        if ($j.InstallLocation -and ($j.AppCategories -contains 'games')) { $d = ($j.InstallLocation -replace '/','\'); if (Test-Path $d) { $GameDirs += $d } }
      } catch {}
    }
  }
} catch {}
# Xbox / Game Pass (each subfolder of C:\XboxGames is a game)
try { if (Test-Path 'C:\XboxGames') { foreach ($d in (Get-ChildItem 'C:\XboxGames' -Directory -ErrorAction SilentlyContinue)) { $GameDirs += (Join-Path $d.FullName 'Content') } } } catch {}
# GOG / EA / Origin / Ubisoft (games-only install roots)
foreach ($r in @("${env:ProgramFiles(x86)}\GOG Galaxy\Games","$env:ProgramFiles\GOG Galaxy\Games",
                 "${env:ProgramFiles(x86)}\Origin Games","$env:ProgramFiles\Origin Games","$env:ProgramFiles\EA Games","${env:ProgramFiles(x86)}\EA Games",
                 "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\games","$env:ProgramFiles\Ubisoft\Ubisoft Game Launcher\games")) {
  try { if (Test-Path $r) { $GameDirs += $r } } catch {}
}
$GameDirs = @($GameDirs | Select-Object -Unique)

# --- code ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Native {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("shell32.dll")] public static extern int SHQueryUserNotificationState(out int s);
  [DllImport("user32.dll")]  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]  public static extern int GetWindowThreadProcessId(IntPtr h, out int p);
  [DllImport("user32.dll")]  public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
"@

function Get-UZT { [DateTime]::UtcNow.AddHours(5) }
function Test-ActiveWindow { if ($Active24x7) { return $true } $h = (Get-UZT).Hour; return ($h -ge $ActiveStartUZT) -or ($h -lt $ActiveEndUZT) }
function Get-Who { try { (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName } catch { "$env:COMPUTERNAME\$env:USERNAME" } }
function Get-ForegroundProc {
  $h = [Native]::GetForegroundWindow(); $procId = 0
  [void][Native]::GetWindowThreadProcessId($h, [ref]$procId)
  try { (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { "" }
}
function Test-Gaming {
  # Detect a game ONLY by reliable signals: a process running from a known game folder
  # (Steam/Epic/GOG/EA/Ubisoft/Xbox) OR a name in the explicit game list. The old
  # fullscreen / borderless-window heuristics were removed because they false-flagged
  # tools (Snipping Tool, screenshot apps), fullscreen video players and editors as "games".
  foreach ($pr in (Get-Process -ErrorAction SilentlyContinue)) {
    $path = $null; try { $path = $pr.Path } catch {}
    if (-not $path) { continue }
    foreach ($sc in $GameDirs) {
      if ($path.StartsWith($sc, [System.StringComparison]::OrdinalIgnoreCase)) {
        $excl = $false
        foreach ($d in $SteamExcludeDirs) { if ($path -like "*\common\$d\*") { $excl = $true; break } }
        if (-not $excl -and ($NonGames -notcontains $pr.ProcessName)) { return @{ on = $true; name = $pr.ProcessName } }
      }
    }
  }
  $running = (Get-Process).ProcessName
  foreach ($g in $GameProcesses) { if ($running -contains $g) { return @{ on = $true; name = $g } } }
  return @{ on = $false; name = $null }
}
function Test-OnScreen {
  $s = 0; [void][Native]::SHQueryUserNotificationState([ref]$s)
  if ($s -eq 3) { if ($NonGames -notcontains (Get-ForegroundProc)) { return $true } }
  $fg = Get-ForegroundProc
  if ($fg -and ($NonGames -notcontains $fg)) {
    $h = [Native]::GetForegroundWindow(); $r = New-Object Native+RECT
    if ([Native]::GetWindowRect($h, [ref]$r)) {
      $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
      foreach ($sc in [System.Windows.Forms.Screen]::AllScreens) {
        if ($w -eq $sc.Bounds.Width -and $ht -eq $sc.Bounds.Height) { return $true }
      }
    }
  }
  return $false
}
function Capture-Screen {
  $p = Join-Path $env:TEMP ("gw_{0}.png" -f (Get-Date -Format yyyyMMddHHmmss))
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  # base: GDI grab of the FULL virtual desktop = every monitor in one image (correct layout)
  $bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try { $g.CopyFromScreen($vs.Location, [System.Drawing.Point]::Empty, $vs.Size) } catch {}
  # exclusive fullscreen: GDI blacks out the game monitor -> overlay a DXGI grab of EACH monitor
  $s = 0; [void][Native]::SHQueryUserNotificationState([ref]$s)
  if ($s -eq 3 -and (Test-Path $FFmpeg)) {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    for ($i = 0; $i -lt $screens.Count; $i++) {
      $mp = Join-Path $env:TEMP ("gw_m{0}_{1}.png" -f $i, (Get-Date -Format HHmmssfff))
      # bounded ffmpeg call (no window flash) - never let ddagrab hang if the game blocks Desktop Duplication
      try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FFmpeg
        $psi.Arguments = "-hide_banner -loglevel error -filter_complex `"ddagrab=output_idx=$i,hwdownload,format=bgra`" -frames:v 1 -y `"$mp`""
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardError = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if (-not $proc.WaitForExit(5000)) { try { $proc.Kill() } catch {}; try { $proc.WaitForExit(1000) } catch {} }
      } catch {}
      if ((Test-Path $mp) -and (Get-Item $mp).Length -gt 2000) {
        try {
          $mi = [System.Drawing.Image]::FromFile($mp)
          $g.DrawImage($mi, ($screens[$i].Bounds.X - $vs.X), ($screens[$i].Bounds.Y - $vs.Y), $screens[$i].Bounds.Width, $screens[$i].Bounds.Height)
          $mi.Dispose()
        } catch {}
        Remove-Item $mp -ErrorAction SilentlyContinue
      }
    }
  }
  $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); return $p
}
function Test-BlankShot($path) {
  # true if the capture is essentially uniform (monitor off / session locked -> transparent or single-colour frame)
  try {
    $img = [System.Drawing.Bitmap]::FromFile($path)
    $w = $img.Width; $h = $img.Height; $seen = @{}
    foreach ($fx in 0.15,0.4,0.6,0.85) { foreach ($fy in 0.15,0.4,0.6,0.85) {
      $px = $img.GetPixel([int]($w*$fx), [int]($h*$fy)); $seen["$($px.A),$($px.R),$($px.G),$($px.B)"] = 1
    } }
    $img.Dispose()
    return ($seen.Keys.Count -le 1)
  } catch { return $false }
}
function Send-Photo($photoPath, $caption) {
  # blank shot (monitor off / session locked) -> send text instead of a white/empty image
  if (Test-BlankShot $photoPath) { Send-Text $caption; return }
  try {
    $cf = Join-Path $env:TEMP ("gw_c_{0}.txt" -f (Get-Date -Format HHmmssfff))
    [System.IO.File]::WriteAllText($cf, [string]$caption, $Enc)
    & curl.exe -s -F "chat_id=$ChatId" -F "caption=<$cf" -F "photo=@$photoPath" "https://api.telegram.org/bot$Token/sendPhoto" | Out-Null
    Remove-Item $cf -ErrorAction SilentlyContinue
  } catch {}
}
function Send-Text($text) {
  try {
    $tf = Join-Path $env:TEMP ("gw_t_{0}.txt" -f (Get-Date -Format HHmmssfff))
    [System.IO.File]::WriteAllText($tf, [string]$text, $Enc)
    & curl.exe -s "https://api.telegram.org/bot$Token/sendMessage" --data-urlencode "chat_id=$ChatId" --data-urlencode "text@$tf" | Out-Null
    Remove-Item $tf -ErrorAction SilentlyContinue
  } catch {}
}
function Log-Session($user, $app, $start, $end) {
  if (-not (Test-Path $LogFile)) { "date,user,app,start,end,duration_min,end_iso" | Out-File $LogFile -Encoding utf8 }
  $dur = [int]($end - $start).TotalMinutes
  ('{0},{1},{2},{3},{4},{5},{6}' -f (Get-Date $start -Format 'yyyy-MM-dd'), $user, $app, (Get-Date $start -Format 'HH:mm:ss'), (Get-Date $end -Format 'HH:mm:ss'), $dur, (Get-Date $end -Format 's')) | Out-File $LogFile -Append -Encoding utf8
}
function Get-State($key) { if (Test-Path $StateFile) { $l = Get-Content $StateFile | Where-Object { $_ -like "$key=*" } | Select-Object -First 1; if ($l) { return $l.Split('=',2)[1] } }; return $null }
function Set-State($key, $val) { $lines = @(); if (Test-Path $StateFile) { $lines = Get-Content $StateFile | Where-Object { $_ -notlike "$key=*" } }; $lines += "$key=$val"; $lines | Out-File $StateFile -Encoding utf8 }
function Send-DailySummary {
  $recent = @()
  if (Test-Path $LogFile) { $cut = (Get-Date).AddHours(-24); $recent = Import-Csv $LogFile | Where-Object { try { [datetime]$_.end_iso -ge $cut } catch { $false } } }
  if (-not $recent -or @($recent).Count -eq 0) { Send-Text "$I_SUM Daily summary on $($env:COMPUTERNAME): no games." ; return }
  $lines = $recent | Group-Object app | ForEach-Object { "  {0}: {1} min ({2} sessions)" -f $_.Name, (($_.Group | Measure-Object -Property duration_min -Sum).Sum), $_.Count }
  $total = ($recent | Measure-Object -Property duration_min -Sum).Sum
  Send-Text ("$I_SUM DAILY SUMMARY on {0}`nTotal: {1}h {2}m`n{3}" -f $env:COMPUTERNAME, [int]($total/60), [int]($total%60), ($lines -join "`n"))
}

# --- auto-update: pull a newer GameWatch.ps1 from the central repo and restart ---
function Update-Self {
  if (-not $UpdateBaseUrl) { return }
  $ProgressPreference = 'SilentlyContinue'   # no progress bar (silent + faster)
  try {
    $base = $UpdateBaseUrl.TrimEnd('/')
    $remote = (Invoke-WebRequest -Uri "$base/version.txt" -UseBasicParsing -TimeoutSec 20).Content
    $rv = 0; [void][int]::TryParse(($remote -replace '\D',''), [ref]$rv)
    if ($rv -le $ScriptVersion) { return }
    # download into the Defender-excluded install folder (never %TEMP%) so no AV scan/popup on employee PCs
    $tmp = Join-Path $Root ("gw_upd_{0}.ps1" -f (Get-Date -Format HHmmssfff))
    Invoke-WebRequest -Uri "$base/GameWatch.ps1" -UseBasicParsing -TimeoutSec 60 -OutFile $tmp
    $c = Get-Content $tmp -Raw
    $errs = $null; [System.Management.Automation.Language.Parser]::ParseInput($c, [ref]$null, [ref]$errs) | Out-Null
    if ($c.Length -gt 3000 -and $c -match '\$ScriptVersion' -and -not ($errs -and $errs.Count)) {
      $self = $PSCommandPath; if (-not $self) { $self = $MyInvocation.MyCommand.Definition }
      Copy-Item $tmp $self -Force
      Remove-Item $tmp -ErrorAction SilentlyContinue
      Send-Text "$I_INFO GameWatch updated to v$rv on $($env:COMPUTERNAME) (was v$ScriptVersion). Restarting."
      $vbs = Join-Path ([Environment]::GetFolderPath('CommonStartup')) 'GameWatch.vbs'
      if (-not (Test-Path $vbs)) { $vbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'GameWatch.vbs' }
      if (Test-Path $vbs) { Start-Process wscript.exe -ArgumentList "`"$vbs`"" }
      exit
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue
  } catch {}
}

# check for a newer version at startup (before doing anything else)
Update-Self

# started / opened on a device -> send info AND a screenshot of all monitors (any time, not gated by watch window)
try {
  $startShot = Capture-Screen
  Send-Photo $startShot "$I_INFO GameWatch started on $($env:COMPUTERNAME)`nUser: $(Get-Who)`nClock now: $((Get-UZT).ToString('HH:mm')) UZT (check it matches real Uzbekistan time)"
  Remove-Item $startShot -ErrorAction SilentlyContinue
} catch {}

$inGame = $false; $gStart = $null; $gApp = $null; $gWho = $null; $lastShot = $null
$lastUpdCheck = Get-Date
while ($true) {
  $uzt = Get-UZT
  $active = Test-ActiveWindow
  if (-not $active -and $inGame) {
    $end = Get-Date; $dur = [int]($end - $gStart).TotalMinutes
    Send-Text "$I_STOP GAME CLOSED (watch window ended) on $($env:COMPUTERNAME)`nUser: $gWho`nApp: $gApp`nPlayed: $dur min"
    Log-Session $gWho $gApp $gStart $end
    $inGame = $false
  }
  if ($active) {
    $r = Test-Gaming
    if ($r.on -and -not $inGame) {
      $inGame = $true; $gStart = Get-Date; $gApp = $r.name; $gWho = Get-Who
      Send-Text "$I_GAME GAME LAUNCH on $($env:COMPUTERNAME)`nUser: $gWho`nApp: $gApp`nTime: $($uzt.ToString('HH:mm')) UZT"
      # wait for the game to be on-screen, but stop if it closes early
      $w = 0; while ($w -lt $FullscreenWaitMax -and -not (Test-OnScreen)) { if (-not (Test-Gaming).on) { break }; Start-Sleep 3; $w += 3 }
      # let it finish loading, but bail out the moment the game closes (no stale/white shot)
      $d = 0; while ($d -lt $CaptureDelaySeconds) { if (-not (Test-Gaming).on) { break }; Start-Sleep 2; $d += 2 }
      if ((Test-Gaming).on) {
        $shot = Capture-Screen
        if ((Test-Gaming).on) {
          Send-Photo $shot "$I_SHOT GAME (fullscreen) on $($env:COMPUTERNAME)`nUser: $gWho`nApp: $gApp`nTime: $((Get-UZT).ToString('HH:mm')) UZT"
        }
        Remove-Item $shot -ErrorAction SilentlyContinue
      }
      $lastShot = Get-Date
    }
    elseif ($r.on -and $inGame) {
      if (((Get-Date) - $lastShot).TotalMinutes -ge $PeriodicScreenshotMin) {
        $dur = [int]((Get-Date) - $gStart).TotalMinutes
        $shot = Capture-Screen
        Send-Photo $shot "$I_LOOP GAME (playing $dur min) on $($env:COMPUTERNAME)`nUser: $gWho`nApp: $gApp`nTime: $((Get-UZT).ToString('HH:mm')) UZT"
        Remove-Item $shot -ErrorAction SilentlyContinue
        $lastShot = Get-Date
      }
    }
    elseif (-not $r.on -and $inGame) {
      $end = Get-Date; $dur = [int]($end - $gStart).TotalMinutes
      Send-Text "$I_STOP GAME CLOSED on $($env:COMPUTERNAME)`nUser: $gWho`nApp: $gApp`nPlayed: $dur min"
      Log-Session $gWho $gApp $gStart $end
      $inGame = $false
    }
  }
  if ($uzt.Hour -eq $SummaryHourUZT -and (Get-State 'lastSummaryDay') -ne $uzt.ToString('yyyy-MM-dd')) {
    Send-DailySummary; Set-State 'lastSummaryDay' $uzt.ToString('yyyy-MM-dd')
  }
  # check for updates periodically (never mid-game, so we don't interrupt a session)
  if (-not $inGame -and ((Get-Date) - $lastUpdCheck).TotalMinutes -ge $UpdateCheckMin) {
    $lastUpdCheck = Get-Date; Update-Self
  }
  Start-Sleep -Seconds $PollSeconds
}
