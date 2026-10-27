@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_sword_v8.ps1"
set "SENU_CUT_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %SENU_CUT_EXPORT_RESULT%
