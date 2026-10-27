param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference = 'Stop'
$menuRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$nativePath = Join-Path $menuRoot 'art\pixelorama\menu_v8\senu_menu_idle_v8.pxo'
$outputPath = Join-Path $menuRoot 'assets\ui\senu_menu_idle_v8.png'
$logPath = Join-Path $menuRoot 'qa\pixelorama_menu_idle_v8.log'
$started = [DateTime]::UtcNow
$process = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $menuRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
    '--rendering-method','gl_compatibility','--log-file',$logPath,
    '--quit-after','1200','--max-fps','60','--','--export','--spritesheet','--json','--output',$outputPath,$nativePath)
if ($process.ExitCode -ne 0) { throw 'Falha ao exportar o retrato animado no Pixelorama.' }
$file = Get-Item -LiteralPath $outputPath
if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw 'O retrato não foi atualizado.' }
if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro na exportação: $logPath" }
Copy-Item -LiteralPath (Join-Path $menuRoot 'art\pixelorama\menu_v8\export_plan.json') -Destination (Join-Path $menuRoot 'assets\ui\senu_menu_idle_v8_manifest.json') -Force
& $GodotPath --headless --path $menuRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Erro na importação do retrato no Godot.' }
Write-Host 'Retrato animado exportado pelo Pixelorama e integrado.'
