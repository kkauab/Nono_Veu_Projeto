@echo off
setlocal
set "SEA_PIXELORAMA=%USERPROFILE%\Downloads\Pixelorama-Windows-64bit\Pixelorama.exe"
if not exist "%SEA_PIXELORAMA%" set "SEA_PIXELORAMA=A:\Ferramentas\Pixelorama\Pixelorama.exe"
if not exist "%SEA_PIXELORAMA%" (
  echo Abra art\pixelorama\sea_v1\boat_v1.pxo e isle_v1.pxo no Pixelorama.
  pause
  exit /b 1
)
start "Pixelorama - Mar" /D "%~dp0" "%SEA_PIXELORAMA%" "%~dp0art\pixelorama\sea_v1\boat_v1.pxo" "%~dp0art\pixelorama\sea_v1\isle_v1.pxo"
