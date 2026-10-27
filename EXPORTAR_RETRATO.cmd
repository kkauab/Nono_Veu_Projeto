@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_menu_idle_v8.ps1"
set "MENU_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %MENU_EXPORT_RESULT%
