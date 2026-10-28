param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe')
)
# Barco de Sabu e Ilha do Bennu: o próprio Pixelorama exporta as duas folhas a
# partir dos projetos nativos, e o Godot reimporta. Os .pxo nascem de build_sea_v1.gd.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
# Os mesmos programas também podem estar em A:\Ferramentas.
if (-not (Test-Path -LiteralPath $PixeloramaPath)) { $PixeloramaPath = 'A:\Ferramentas\Pixelorama\Pixelorama.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { $GodotPath = 'A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe' }
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'qa') | Out-Null
foreach ($sheet in @('boat_v1', 'isle_v1')) {
    $nativePath = Join-Path $projectRoot "art\pixelorama\sea_v1\$sheet.pxo"
    $outputPath = Join-Path $projectRoot "assets\world\$sheet.png"
    $logPath = Join-Path $projectRoot "qa\pixelorama_$sheet.log"
    $startedAt = [DateTime]::UtcNow
    # Start-Process junta os argumentos sem aspas: caminhos com espaço ("A:\nono veu") se partiriam.
    $arguments = @('--rendering-method', 'gl_compatibility', '--log-file', "`"$logPath`"",
        '--quit-after', '1200', '--max-fps', '60', '--', '--export', '--json', '--spritesheet',
        '--output', "`"$outputPath`"", "`"$nativePath`"")
    $process = Start-Process -FilePath $PixeloramaPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Pixelorama falhou: $sheet" }
    $file = Get-Item -LiteralPath $outputPath
    if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) { throw "Exportação não atualizada: $sheet" }
    if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no registro: $logPath" }
    Copy-Item -LiteralPath (Join-Path $projectRoot "art\pixelorama\sea_v1\${sheet}_export_plan.json") -Destination (Join-Path $projectRoot "assets\world\${sheet}_manifest.json") -Force
    Write-Host "Pixelorama exportou $sheet."
}
& $GodotPath --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'O Godot encontrou erro na importação.' }
Write-Host 'Barco e ilha exportados. Reabra JOGAR.cmd.'
