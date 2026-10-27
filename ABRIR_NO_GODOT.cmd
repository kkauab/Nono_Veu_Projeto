@echo off
setlocal
set "GAME_GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
if not exist "%GAME_GODOT%" (
  echo Godot nao encontrado em Downloads. Importe project.godot no gerenciador de projetos do Godot 4.
  pause
  exit /b 1
)
start "Godot - O Nono Veu" /D "%~dp0" "%GAME_GODOT%" --editor --path "%~dp0."
exit /b 0
