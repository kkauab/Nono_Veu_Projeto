@echo off
setlocal
set "PORTEIRO_GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
if not exist "%PORTEIRO_GODOT%" set "PORTEIRO_GODOT=A:\Ferramentas\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%PORTEIRO_GODOT%" (
  echo Godot 4.7.2 nao encontrado. Abra o projeto no Godot para importar os recursos.
  pause
  exit /b 1
)
echo Porteiro: caminhada no mapa e nove animacoes de ataque.
echo 1-9 escolhem um golpe. Tab alterna a sequencia automatica.
echo Previa de arte em progresso separado, sem dano ou recompensas.
set "PORTEIRO_IMPORT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%PORTEIRO_IMPORT%" set "PORTEIRO_IMPORT=%PORTEIRO_GODOT%"
if not exist "%~dp0qa" mkdir "%~dp0qa"
"%PORTEIRO_IMPORT%" --headless --editor --path "%~dp0." --import --quit > "%~dp0qa\porteiro_startup_import.log" 2>&1
if errorlevel 1 (
  echo Falha na importacao. Consulte qa\porteiro_startup_import.log.
  pause
  exit /b 1
)
start "Porteiro - estudo de movimentos" /D "%~dp0" "%PORTEIRO_GODOT%" --path "%~dp0." --script tests/gatekeeper_rehearsal.gd -- --qa
