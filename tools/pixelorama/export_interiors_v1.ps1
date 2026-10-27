param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe')
)
# Móveis e lojistas das casas: o próprio Pixelorama exporta a folha a partir do
# projeto nativo, e o Godot reimporta. O .pxo nasce de build_interiors_v1.gd.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
# Os mesmos programas também podem estar em A:\Ferramentas.
if (-not (Test-Path -LiteralPath $PixeloramaPath)) { $PixeloramaPath = 'A:\Ferramentas\Pixelorama\Pixelorama.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { $GodotPath = 'A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe' }
$nativePath = Join-Path $projectRoot 'art\pixelorama\interiors_v1\interiors_v1.pxo'
$outputPath = Join-Path $projectRoot 'assets\world\interiors_v1.png'
$logPath = Join-Path $projectRoot 'qa\pixelorama_interiors_v1.log'
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'qa') | Out-Null
$startedAt = [DateTime]::UtcNow
# Start-Process junta os argumentos sem aspas: caminhos com espaço ("A:\nono veu") se partiriam.
$arguments = @('--rendering-method', 'gl_compatibility', '--log-file', "`"$logPath`"",
    '--quit-after', '1200', '--max-fps', '60', '--', '--export', '--json', '--spritesheet',
    '--output', "`"$outputPath`"", "`"$nativePath`"")
$process = Start-Process -FilePath $PixeloramaPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw 'Pixelorama falhou: interiors_v1' }
$file = Get-Item -LiteralPath $outputPath
if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) { throw 'Exportação não atualizada: interiors_v1' }
if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro no registro: $logPath" }
Write-Host 'Pixelorama exportou interiors_v1.'
Copy-Item -LiteralPath (Join-Path $projectRoot 'art\pixelorama\interiors_v1\export_plan.json') -Destination (Join-Path $projectRoot 'assets\world\interiors_v1_manifest.json') -Force
& $GodotPath --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'O Godot encontrou erro na importação.' }
Write-Host 'Interiores exportados. Reabra JOGAR.cmd.'
