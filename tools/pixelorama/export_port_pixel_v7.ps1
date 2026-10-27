param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
foreach ($item in @(
    @('port_pixel_v7', 'assets\world'),
    @('port_title_v7', 'assets\ui'),
    @('senu_portrait_v7', 'assets\ui')
)) {
    $name = $item[0]
    $nativePath = Join-Path $projectRoot "art\pixelorama\port_v7\$name.pxo"
    $outputPath = Join-Path $projectRoot "$($item[1])\$name.png"
    $logPath = Join-Path $projectRoot "qa\pixelorama_$name.log"
    $startedAt = [DateTime]::UtcNow
    $arguments = @('--rendering-method', 'gl_compatibility', '--log-file', $logPath,
        '--quit-after', '1200', '--max-fps', '60', '--', '--export', '--json')
    if ($name -eq 'port_pixel_v7') { $arguments += '--spritesheet' }
    $arguments += @('--output', $outputPath, $nativePath)
    $process = Start-Process -FilePath $PixeloramaPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Pixelorama falhou: $name" }
    $file = Get-Item -LiteralPath $outputPath
    if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) { throw "Exportação não atualizada: $name" }
    if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no registro: $logPath" }
    Write-Host "Pixelorama exportou $name."
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'art\pixelorama\port_v7\export_plan.json') -Destination (Join-Path $projectRoot 'assets\world\port_pixel_v7_manifest.json') -Force
& $GodotPath --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'O Godot encontrou erro na importação.' }
Write-Host 'Cenário e menus pixelados exportados. Reabra JOGAR.cmd.'
