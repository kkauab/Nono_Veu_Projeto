@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_opening_rpg_v11.ps1"
set "OPENING_EXPORT_RESULT=%ERRORLEVEL%"
if not "%OPENING_EXPORT_RESULT%"=="0" goto done
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_fisherman_v13.ps1"
set "OPENING_EXPORT_RESULT=%ERRORLEVEL%"
if not "%OPENING_EXPORT_RESULT%"=="0" goto done
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_opening_boat_v12.ps1"
set "OPENING_EXPORT_RESULT=%ERRORLEVEL%"
if not "%OPENING_EXPORT_RESULT%"=="0" goto done
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pixelorama\export_dialogue_portraits_v15.ps1"
set "OPENING_EXPORT_RESULT=%ERRORLEVEL%"
:done
pause
exit /b %OPENING_EXPORT_RESULT%

