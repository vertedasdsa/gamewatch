# Test Telegram Bot Configuration

param(
  [string]$Token,
  [string]$ChatId
)

Write-Host "=== MicroTyk Telegram Connection Test ===" -ForegroundColor Cyan
Write-Host ""

# Load config if not provided
if (-not $Token -or -not $ChatId) {
  $cfg = "D:\gamewatch\config.ps1"
  if (Test-Path $cfg) {
    Write-Host "Loading config from: $cfg" -ForegroundColor Yellow
    . $cfg
  } else {
    Write-Host "ERROR: config.ps1 not found or Token/ChatId not provided" -ForegroundColor Red
    Write-Host "Usage: .\TEST-Telegram.ps1 -Token 'YOUR_TOKEN' -ChatId 'YOUR_CHAT_ID'" -ForegroundColor Yellow
    exit 1
  }
}

if (-not $Token -or $Token -like "*YOUR_*") {
  Write-Host "ERROR: Token is empty or not configured" -ForegroundColor Red
  Write-Host "Edit D:\gamewatch\config.ps1 with your actual bot token" -ForegroundColor Yellow
  exit 1
}

if (-not $ChatId -or $ChatId -like "*YOUR_*") {
  Write-Host "ERROR: ChatId is empty or not configured" -ForegroundColor Red
  Write-Host "Edit D:\gamewatch\config.ps1 with your actual chat ID" -ForegroundColor Yellow
  exit 1
}

Write-Host "Token: $($Token.Substring(0, 10))..." -ForegroundColor Green
Write-Host "ChatId: $ChatId" -ForegroundColor Green
Write-Host ""

# Test 1: Bot Info
Write-Host "[Test 1] Verifying bot token..." -ForegroundColor Yellow
try {
  $response = Invoke-WebRequest "https://api.telegram.org/bot$Token/getMe" -UseBasicParsing -TimeoutSec 10
  $data = $response.Content | ConvertFrom-Json

  if ($data.ok) {
    Write-Host "✅ Bot connected!" -ForegroundColor Green
    Write-Host "   Bot name: @$($data.result.username)" -ForegroundColor Gray
    Write-Host "   Bot ID: $($data.result.id)" -ForegroundColor Gray
  } else {
    Write-Host "❌ Bot error: $($data.description)" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Connection failed: $_" -ForegroundColor Red
  exit 1
}

Write-Host ""

# Test 2: Send Test Message
Write-Host "[Test 2] Sending test message..." -ForegroundColor Yellow
try {
  $testMsg = "🚀 MicroTyk test: Connection successful at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $response = Invoke-WebRequest `
    "https://api.telegram.org/bot$Token/sendMessage" `
    -Body @{ chat_id = $ChatId; text = $testMsg } `
    -UseBasicParsing `
    -TimeoutSec 10

  $data = $response.Content | ConvertFrom-Json

  if ($data.ok) {
    Write-Host "✅ Message sent!" -ForegroundColor Green
    Write-Host "   Message ID: $($data.result.message_id)" -ForegroundColor Gray
    Write-Host "   Check Telegram for: $testMsg" -ForegroundColor Gray
  } else {
    Write-Host "❌ Send failed: $($data.description)" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Send error: $_" -ForegroundColor Red
  exit 1
}

Write-Host ""

# Test 3: Get Updates
Write-Host "[Test 3] Checking chat..." -ForegroundColor Yellow
try {
  $response = Invoke-WebRequest "https://api.telegram.org/bot$Token/getUpdates" -UseBasicParsing -TimeoutSec 10
  $data = $response.Content | ConvertFrom-Json

  if ($data.result.Count -gt 0) {
    $lastMsg = $data.result[-1].message
    Write-Host "✅ Chat active!" -ForegroundColor Green
    Write-Host "   Last message: '$($lastMsg.text)'" -ForegroundColor Gray
    Write-Host "   From: $($lastMsg.from.username)" -ForegroundColor Gray
  } else {
    Write-Host "⚠️  No recent messages (normal if you haven't sent any)" -ForegroundColor Yellow
  }
} catch {
  Write-Host "⚠️  Updates check skipped: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All tests passed! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Check Telegram for test message" -ForegroundColor Gray
Write-Host "  2. Start MicroTyk: powershell -NoProfile -WindowStyle Hidden -File D:\gamewatch\MicroTyk.ps1" -ForegroundColor Gray
Write-Host "  3. Launch a game and check for screenshots" -ForegroundColor Gray
