@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_dialogue_portraits_v15.ps1"
set "DIALOGUE_EXPORT_RESULT=%ERRORLEVEL%"
pause
exit /b %DIALOGUE_EXPORT_RESULT%

