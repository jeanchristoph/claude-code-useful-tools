@echo off
:: Launches the call-mute watcher next to this file. Nothing is changed on the system:
:: -ExecutionPolicy Bypass applies to this process only. Close the window or press Ctrl+C to stop.
title Mute call while dictating (Claude Code)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0mute-call-while-dictating.ps1"
if errorlevel 1 pause
