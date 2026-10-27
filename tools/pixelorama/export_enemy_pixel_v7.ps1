param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference = 'Stop'
$enemyRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$nativePath = Join-Path $enemyRoot 'art\pixelorama\enemies_v7\port_enemies_v7.pxo'
$outputPath = Join-Path $enemyRoot 'assets\sprites\port_enemies_v7.png'
$logPath = Join-Path $enemyRoot 'qa\pixelorama_enemies_v7.log'
$startedAt = [DateTime]::UtcNow
$process = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $enemyRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
    '--rendering-method', 'gl_compatibility', '--log-file', $logPath,
    '--quit-after', '1200', '--max-fps', '60', '--', '--export', '--spritesheet', '--json',
    '--output', $outputPath, $nativePath
)
if ($process.ExitCode -ne 0) { throw 'Pixelorama não concluiu a exportação dos inimigos.' }
$file = Get-Item -LiteralPath $outputPath
if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) { throw 'O PNG não foi atualizado.' }
if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro em $logPath" }
Copy-Item -LiteralPath (Join-Path $enemyRoot 'art\pixelorama\enemies_v7\export_plan.json') -Destination (Join-Path $enemyRoot 'assets\sprites\port_enemies_v7_manifest.json') -Force
& $GodotPath --headless --path $enemyRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot encontrou erro na importação.' }
Write-Host 'Sentinelas pixelados exportados pelo Pixelorama e importados no Godot.'
