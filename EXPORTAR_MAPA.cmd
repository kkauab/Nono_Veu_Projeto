@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_port_pixel_v7.ps1"
set "PORT_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %PORT_EXPORT_RESULT%
