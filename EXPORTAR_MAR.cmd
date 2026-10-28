@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_sea_v1.ps1"
set "SEA_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %SEA_EXPORT_RESULT%
