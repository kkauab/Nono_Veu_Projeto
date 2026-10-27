@echo off
setlocal
set "INTERIORS_PIXELORAMA=%USERPROFILE%\Downloads\Pixelorama-Windows-64bit\Pixelorama.exe"
if not exist "%INTERIORS_PIXELORAMA%" set "INTERIORS_PIXELORAMA=A:\Ferramentas\Pixelorama\Pixelorama.exe"
if not exist "%INTERIORS_PIXELORAMA%" (
  echo Abra art\pixelorama\interiors_v1\interiors_v1.pxo no Pixelorama.
  pause
  exit /b 1
)
start "Pixelorama - Interiores" /D "%~dp0" "%INTERIORS_PIXELORAMA%" "%~dp0art\pixelorama\interiors_v1\interiors_v1.pxo"
