# ============================================================
#  MicroTyk Configuration (Local Secrets)
#  NOT included in GitHub repo for security
# ============================================================

# Telegram Bot API Token
# Get from BotFather: @BotFather → /newbot → /token
$Token = "YOUR_TELEGRAM_BOT_TOKEN"

# Telegram Chat ID (where to send screenshots)
# Get from @userinfobot or your private chat with the bot
# Format: numeric string (e.g. "6083023650" or "-5433148319" for groups)
$ChatId = "YOUR_TELEGRAM_CHAT_ID"

# Optional: Override settings from main script
# $ExtraGameProcesses = @("MyGame.exe", "CustomGame.exe")     # Add custom game executables
# $PeriodicScreenshotMin = 20                                  # Screenshot interval (minutes)
# $Active24x7 = $true                                          # Monitor 24/7 (or $false for time window)
# $ActiveStartUZT = 17                                         # Start time if not 24/7 (UZT hours)
# $ActiveEndUZT = 4                                            # End time if not 24/7 (UZT hours)
