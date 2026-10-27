@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_enemy_pixel_v12.ps1"
set "ENEMY_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %ENEMY_EXPORT_RESULT%
