param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'),
    [ValidateSet(1,2,3,4,5,6)][int]$ArtVersion = 1
)
$ErrorActionPreference = 'Stop'
$gatekeeperRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$stem = if ($ArtVersion -eq 6) { 'porteiro_walk_v6' } else { "porteiro_v$ArtVersion" }
$nativePath = Join-Path $gatekeeperRoot "art\pixelorama\$stem\$stem.pxo"
$outputPath = Join-Path $gatekeeperRoot "assets\sprites\$stem.png"
$qaDir = if ($ArtVersion -eq 6) { 'qa\porteiro_walk_v6' } elseif ($ArtVersion -eq 5) { 'qa\porteiro_attacks_v5' } else { "qa\porteiro_art_v$ArtVersion" }
$logPath = Join-Path $gatekeeperRoot "$qaDir\pixelorama_export.log"
$hashPath = Join-Path $gatekeeperRoot "art\pixelorama\$stem\exported_hashes.json"
$manifestPath = Join-Path $gatekeeperRoot "assets\sprites\${stem}_manifest.json"
$previousHashes = @{}
if (Test-Path -LiteralPath $hashPath) {
    $stored = Get-Content -LiteralPath $hashPath -Raw | ConvertFrom-Json
    foreach ($entry in $stored.PSObject.Properties) { $previousHashes[$entry.Name] = $entry.Value }
}
foreach ($candidate in @($outputPath, [IO.Path]::ChangeExtension($outputPath, '.json'), $manifestPath)) {
    if ((Test-Path -LiteralPath $candidate) -and ((Get-FileHash -LiteralPath $candidate).Hash -ne $previousHashes[$candidate])) {
        throw "Edicao manual ou arquivo sem registro preservado: $candidate. Exporte para uma nova versao."
    }
}
$startedAt = [DateTime]::UtcNow
$stagingDir = Join-Path $gatekeeperRoot ("$qaDir\export_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingDir | Out-Null
$stagingPath = Join-Path $stagingDir "$stem.png"
# Export to a fresh path: the GUI exporter may require an overwrite decision
# for an existing destination. Preserve the previous atlas until success.
$arguments = '--rendering-method gl_compatibility --log-file "{0}" --quit-after 1800 --max-fps 60 -- --export --spritesheet --json --output "{1}" "{2}"' -f $logPath, $stagingPath, $nativePath
$exportProcess = Start-Process -FilePath $PixeloramaPath -WorkingDirectory $gatekeeperRoot -WindowStyle Hidden -Wait -PassThru -ArgumentList $arguments
if ($exportProcess.ExitCode -ne 0) { throw "Pixelorama nao concluiu a exportacao do Porteiro (saida $($exportProcess.ExitCode))." }
$exported = Get-Item -LiteralPath $stagingPath
if ($exported.Length -eq 0 -or $exported.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) { throw 'O PNG nao foi atualizado.' }
if ([IO.File]::ReadAllText($logPath) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro em $logPath" }
Copy-Item -LiteralPath $stagingPath -Destination $outputPath
Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($stagingPath, '.json')) -Destination ([IO.Path]::ChangeExtension($outputPath, '.json'))
Copy-Item -LiteralPath (Join-Path $gatekeeperRoot "art\pixelorama\$stem\export_plan.json") -Destination $manifestPath
$newHashes = @{}
foreach ($candidate in @($outputPath, [IO.Path]::ChangeExtension($outputPath, '.json'), $manifestPath)) {
    $newHashes[$candidate] = (Get-FileHash -LiteralPath $candidate).Hash
}
$newHashes | ConvertTo-Json | Set-Content -LiteralPath $hashPath -Encoding utf8
& $GodotPath --headless --editor --path $gatekeeperRoot --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot encontrou erro na importacao.' }
$plan = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Write-Output "Porteiro v${ArtVersion}: $($plan.frames) quadros de estudo exportados pelo Pixelorama; arte ainda nao ligada ao combate."
