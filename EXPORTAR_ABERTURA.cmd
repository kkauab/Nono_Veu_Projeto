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
"%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --editor --import --quit
set "OPENING_EXPORT_RESULT=%ERRORLEVEL%"
:done
pause
exit /b %OPENING_EXPORT_RESULT%
