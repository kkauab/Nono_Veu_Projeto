@echo off
setlocal
set "GAME_GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
if not exist "%GAME_GODOT%" (
  echo Godot nao encontrado em Downloads. Abra project.godot no Godot 4 e pressione F6 na cena main, ou F5 para jogar.
  pause
  exit /b 1
)
start "O Nono Veu" /D "%~dp0" "%GAME_GODOT%" --path "%~dp0."
exit /b 0
