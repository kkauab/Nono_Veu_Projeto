param(
 [string]$PixeloramaPath=(Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
 [string]$GodotPath=(Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'),
 [string]$PythonPath=(Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'),
 [string]$StagingDirectory='',
 [ValidateSet(7,8,9)][int]$ArtVersion=7
)
$ErrorActionPreference='Stop'
$porteiroRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$porteiroStage=if ($StagingDirectory) { [IO.Path]::GetFullPath($StagingDirectory) } else { Join-Path $porteiroRoot ('qa\porteiro_combate\export_'+[Guid]::NewGuid().ToString('N')) }
if (-not $porteiroStage.StartsWith((Join-Path $porteiroRoot 'qa\porteiro_combate\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Pasta de exportacao fora do QA do projeto.' }
New-Item -ItemType Directory -Path $porteiroStage -Force | Out-Null
& $PythonPath -B (Join-Path $PSScriptRoot 'split_gatekeeper_live_v7.py') $ArtVersion
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar fontes direcionais.' }
$porteiroOutputs=@{}
foreach ($porteiroDirection in @('right','down_right','down','down_left','left','up_left','up','up_right')) {
 $porteiroRaw=Join-Path $porteiroStage ($porteiroDirection+'.png')
 $porteiroNative=Join-Path $porteiroRoot ('art\pixelorama\porteiro_live_v'+$ArtVersion+'\directions\'+$porteiroDirection+'.pxo')
 $porteiroLog=Join-Path $porteiroStage ($porteiroDirection+'.log')
 $porteiroArgs='--rendering-method gl_compatibility --log-file "{0}" --quit-after 1800 --max-fps 60 -- --export --spritesheet --json --output "{1}" "{2}"' -f $porteiroLog,$porteiroRaw,$porteiroNative
 if (-not (Test-Path -LiteralPath $porteiroRaw)) {
  for ($porteiroAttempt=1; $porteiroAttempt -le 3; $porteiroAttempt++) {
   $porteiroProcess=Start-Process -FilePath $PixeloramaPath -WorkingDirectory $porteiroRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList $porteiroArgs
   if ($porteiroProcess.ExitCode -eq 0) { break }
   Write-Output "Repetindo inicializacao do Pixelorama: $porteiroDirection ($porteiroAttempt/3)"
  }
  if ($porteiroProcess.ExitCode -ne 0) { throw "Pixelorama falhou em $porteiroDirection : $($porteiroProcess.ExitCode)" }
 }
 if ([IO.File]::ReadAllText($porteiroLog) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro em $porteiroLog" }
 $porteiroOutputs[$porteiroDirection]=$porteiroRaw
 Write-Output "Porteiro exportado: $porteiroDirection"
}
$porteiroPaths=Join-Path $porteiroStage 'paths.json'
$porteiroOutputs | ConvertTo-Json | Set-Content -LiteralPath $porteiroPaths -Encoding utf8
& $PythonPath -B (Join-Path $PSScriptRoot 'pack_gatekeeper_live_v7.py') $porteiroPaths $ArtVersion
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar atlas compacto.' }
& $GodotPath --headless --editor --path $porteiroRoot --log-file (Join-Path $porteiroRoot 'qa\porteiro_combate\import_live.log') --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Falha na importacao do Godot.' }
if ([IO.File]::ReadAllText((Join-Path $porteiroRoot 'qa\porteiro_combate\import_live.log')) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw 'O Godot registrou erros; confira import_live.log.' }
