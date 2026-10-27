@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_shared_senu_v6.ps1"
set "SENU_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %SENU_EXPORT_RESULT%
