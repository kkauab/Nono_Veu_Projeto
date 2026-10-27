@echo off
setlocal
set "SENU_PIXELORAMA=%USERPROFILE%\Downloads\Pixelorama-Windows-64bit\Pixelorama.exe"
if not exist "%SENU_PIXELORAMA%" (
  echo Pixelorama nao encontrado em Downloads. Abra art\pixelorama\senu\senu_shared_v6.pxo no Pixelorama.
  pause
  exit /b 1
)
start "Pixelorama - Senu movimento" /D "%~dp0" "%SENU_PIXELORAMA%" "%~dp0art\pixelorama\senu\senu_shared_v6.pxo"
exit /b 0
