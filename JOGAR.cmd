@echo off
setlocal
set "GAME_GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
rem No PC do Gustavo o Godot fica em A:\Ferramentas\godot, nao em Downloads.
if not exist "%GAME_GODOT%" set "GAME_GODOT=A:\Ferramentas\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GAME_GODOT%" (
  echo Godot nao encontrado em Downloads nem em A:\Ferramentas\godot. Abra project.godot no Godot 4 e pressione F6 na cena main, ou F5 para jogar.
  pause
  exit /b 1
)
set "GAME_GODOT_IMPORT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GAME_GODOT_IMPORT%" set "GAME_GODOT_IMPORT=A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GAME_GODOT_IMPORT%" set "GAME_GODOT_IMPORT=%GAME_GODOT%"
if not exist "%~dp0qa" mkdir "%~dp0qa"
echo Preparando os arquivos do jogo. Aguarde...
"%GAME_GODOT_IMPORT%" --headless --editor --path "%~dp0." --import --quit > "%~dp0qa\startup_import.log" 2>&1
if errorlevel 1 (
  echo Nao foi possivel preparar os arquivos. Consulte qa\startup_import.log.
  pause
  exit /b 1
)
start "O Nono Veu" /D "%~dp0" "%GAME_GODOT%" --path "%~dp0."
exit /b 0
