@echo off
REM ============================================================
REM  GameWatch Status Check (one-click)
REM  Check all dispatcher PCs online/offline status
REM  Sends report to Telegram
REM ============================================================

setlocal enabledelayedexpansion

cls
echo.
echo ========================================
echo   GameWatch Status Check
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "D:\gamewatch\Status-Check.ps1" -SaveToFile

echo.
pause
