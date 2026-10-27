@echo off
setlocal
set "PORT_PIXELORAMA=%USERPROFILE%\Downloads\Pixelorama-Windows-64bit\Pixelorama.exe"
if not exist "%PORT_PIXELORAMA%" (
  echo Abra art\pixelorama\port_v7\port_pixel_v7.pxo no Pixelorama.
  pause
  exit /b 1
)
start "Pixelorama - Porto" /D "%~dp0" "%PORT_PIXELORAMA%" "%~dp0art\pixelorama\port_v7\port_pixel_v7.pxo"
