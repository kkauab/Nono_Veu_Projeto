@echo off
setlocal
set "SENU_PIXELORAMA=%USERPROFILE%\Downloads\Pixelorama-Windows-64bit\Pixelorama.exe"
if not exist "%SENU_PIXELORAMA%" (
  echo Abra art\pixelorama\senu\senu_sword_v8.pxo no Pixelorama.
  pause
  exit /b 1
)
start "Pixelorama - Senu combate" /D "%~dp0" "%SENU_PIXELORAMA%" "%~dp0art\pixelorama\senu\senu_sword_v8.pxo"
