@echo off
powershell.exe -NoProfile -NoLogo -ExecutionPolicy ByPass -File "%~dp0Import-Intune.ps1"
pause