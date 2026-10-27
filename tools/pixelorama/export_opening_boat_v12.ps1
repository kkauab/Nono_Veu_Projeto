param([string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'))
$ErrorActionPreference = 'Stop'
$boatRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$boatSource = Join-Path $boatRoot 'art\pixelorama\opening_boat_v12\arrival_boat.pxo'
$boatPng = Join-Path $boatRoot 'assets\cinematics\rpg_v12\arrival_boat.png'
$boatLog = Join-Path $boatRoot 'qa\pixelorama_opening_boat_v12.log'
$boatStarted = [DateTime]::UtcNow
$boatProcess = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $boatRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
    '--rendering-method','gl_compatibility','--log-file',$boatLog,'--quit-after','1200','--max-fps','60','--',
    '--export','--spritesheet','--json','--output',$boatPng,$boatSource)
if ($boatProcess.ExitCode -ne 0) { throw 'O Pixelorama não concluiu o barco da abertura.' }
$boatFile = Get-Item -LiteralPath $boatPng
if ($boatFile.Length -eq 0 -or $boatFile.LastWriteTimeUtc -lt $boatStarted.AddSeconds(-2)) { throw 'O PNG do barco não foi atualizado.' }
if ([IO.File]::ReadAllText($boatLog) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no Pixelorama: $boatLog" }
Copy-Item -LiteralPath (Join-Path $boatRoot 'art\pixelorama\opening_boat_v12\export_plan.json') -Destination (Join-Path $boatRoot 'assets\cinematics\rpg_v12\arrival_boat_manifest.json') -Force
Write-Host 'Barco isométrico exportado pelo Pixelorama: assets/cinematics/rpg_v12/arrival_boat.png'
