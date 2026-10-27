param([string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'))
$ErrorActionPreference = 'Stop'
$introRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path $introRoot 'art\pixelorama\opening_rpg_v11\intro_atlas.pxo'
$png = Join-Path $introRoot 'assets\cinematics\rpg_v11\intro_atlas.png'
$log = Join-Path $introRoot 'qa\pixelorama_opening_rpg_v11.log'
$started = [DateTime]::UtcNow
$process = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $introRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
 '--rendering-method','gl_compatibility','--log-file',$log,'--quit-after','1200','--max-fps','60','--','--export','--spritesheet','--json','--output',$png,$source)
if ($process.ExitCode -ne 0) { throw 'O Pixelorama não concluiu o atlas da abertura.' }
$file=Get-Item -LiteralPath $png
if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw 'O PNG da abertura não foi atualizado.' }
if ([IO.File]::ReadAllText($log) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no Pixelorama: $log" }
Copy-Item -LiteralPath (Join-Path $introRoot 'art\pixelorama\opening_rpg_v11\export_plan.json') -Destination (Join-Path $introRoot 'assets\cinematics\rpg_v11\intro_atlas_manifest.json') -Force
Write-Host 'Abertura original exportada pelo Pixelorama: assets/cinematics/rpg_v11/intro_atlas.png'
