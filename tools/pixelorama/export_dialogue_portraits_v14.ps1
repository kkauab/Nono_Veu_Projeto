param(
 [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
 [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference = 'Stop'
$portraitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
foreach ($character in @('senu','fisherman')) {
 $source = Join-Path $portraitRoot "art\pixelorama\dialogue_v14\$character.pxo"
 $png = Join-Path $portraitRoot "assets\ui\dialogue_v14\$character.png"
 $log = Join-Path $portraitRoot "qa\pixelorama_dialogue_v14_$character.log"
 $started = [DateTime]::UtcNow
 $process = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $portraitRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
  '--rendering-method','gl_compatibility','--log-file',$log,'--quit-after','1800','--max-fps','60','--','--export','--spritesheet','--json','--output',$png,$source)
 if ($process.ExitCode -ne 0) { throw "O Pixelorama não concluiu o retrato de $character." }
 $file = Get-Item -LiteralPath $png
 if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw "O PNG de $character não foi atualizado." }
 if ([IO.File]::ReadAllText($log) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no Pixelorama: $log" }
 Write-Host "Retrato de $character exportado pelo Pixelorama."
}
Copy-Item -LiteralPath (Join-Path $portraitRoot 'art\pixelorama\dialogue_v14\export_plan.json') -Destination (Join-Path $portraitRoot 'assets\ui\dialogue_v14\portrait_manifest.json') -Force
& $GodotPath --headless --path $portraitRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot encontrou erro ao importar os retratos.' }
Write-Host 'Dois retratos animados exportados e importados no Godot.'
