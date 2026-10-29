@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_interiors_v4.ps1"
set "INTERIORS_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %INTERIORS_EXPORT_RESULT%
