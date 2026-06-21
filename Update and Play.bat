@echo off
title LiveReins - Install ^& Play
echo Close R.E.P.O first. This installs/updates the LiveReins mods, then launches.
echo.
echo Fetching latest installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest 'https://raw.githubusercontent.com/itsJmikee/itsjmikee-mods/main/setup.ps1' -OutFile '%~dp0setup.ps1' -UseBasicParsing; Write-Host 'Installer up to date.' -ForegroundColor Green } catch { Write-Host 'Could not fetch latest installer - using local copy.' -ForegroundColor Yellow }"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
