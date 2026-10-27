param([string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'))
$ErrorActionPreference = 'Stop'
$fisherRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path $fisherRoot 'art\pixelorama\fisherman_v13\fisherman.pxo'
$png = Join-Path $fisherRoot 'assets\cinematics\rpg_v12\fisherman.png'
$log = Join-Path $fisherRoot 'qa\pixelorama_fisherman_v13.log'
$started = [DateTime]::UtcNow
$process = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $fisherRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
 '--rendering-method','gl_compatibility','--log-file',$log,'--quit-after','1200','--max-fps','60','--','--export','--spritesheet','--json','--output',$png,$source)
if ($process.ExitCode -ne 0) { throw 'O Pixelorama não concluiu o pescador.' }
$file=Get-Item -LiteralPath $png
if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw 'O PNG do pescador não foi atualizado.' }
if ([IO.File]::ReadAllText($log) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no Pixelorama: $log" }
Copy-Item -LiteralPath (Join-Path $fisherRoot 'art\pixelorama\fisherman_v13\export_plan.json') -Destination (Join-Path $fisherRoot 'assets\cinematics\rpg_v12\fisherman_manifest.json') -Force
Write-Host 'Pescador exportado pelo Pixelorama.'
