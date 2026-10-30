param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'),
    [switch]$SkipImport
)
# Export only. Existing authored cels and every nonwalking v3 source stay intact.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not (Test-Path -LiteralPath $PixeloramaPath)) { $PixeloramaPath = 'A:\Ferramentas\Pixelorama\Pixelorama.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { $GodotPath = 'A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $PixeloramaPath)) { throw "Pixelorama não encontrado: $PixeloramaPath" }
if (-not $SkipImport -and -not (Test-Path -LiteralPath $GodotPath)) { throw "Godot não encontrado: $GodotPath" }
$sheet = 'npc_walk_v4'
$nativePath = Join-Path $projectRoot "art/pixelorama/npc_walk_v4/$sheet.pxo"
$planPath = Join-Path $projectRoot "art/pixelorama/npc_walk_v4/${sheet}_export_plan.json"
if (-not (Test-Path -LiteralPath $nativePath) -or -not (Test-Path -LiteralPath $planPath)) { throw "Projeto/plano ausente: $sheet" }
$qaPath = Join-Path $projectRoot 'qa/npc_walk_v4'
New-Item -ItemType Directory -Force $qaPath | Out-Null
$outputPath = Join-Path $projectRoot "assets/world/$sheet.png"
$jsonPath = Join-Path $projectRoot "assets/world/$sheet.json"
$logPath = Join-Path $qaPath "pixelorama_$sheet.log"
$startedAt = [DateTime]::UtcNow
$arguments = @('--rendering-method', 'gl_compatibility', '--log-file', "`"$logPath`"", '--quit-after', '1200', '--max-fps', '60', '--', '--export', '--json', '--spritesheet', '--output', "`"$outputPath`"", "`"$nativePath`"")
$process = Start-Process -FilePath $PixeloramaPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Pixelorama falhou: $sheet" }
foreach ($path in @($outputPath, $jsonPath)) {
    $file = Get-Item -LiteralPath $path
    if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) { throw "Exportação não atualizada: $path" }
}
if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no registro: $logPath" }
Copy-Item -LiteralPath $planPath -Destination (Join-Path $projectRoot "assets/world/${sheet}_manifest.json") -Force
Write-Host "Pixelorama exportou $sheet."
if (-not $SkipImport) {
    & $GodotPath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'O Godot encontrou erro na importação.' }
}
