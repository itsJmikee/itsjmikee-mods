@echo off
title Puppeteer - Install ^& Play
echo Close R.E.P.O first. This installs/updates the Puppeteer mods, then launches.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
