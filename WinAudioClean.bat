@echo off
REM WinAudioClean Droplet
REM Passes the dropped file path to the PowerShell script
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinAudioClean.ps1" "%~1"
pause