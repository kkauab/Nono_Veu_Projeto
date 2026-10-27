param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'),
    [string]$PythonPath = (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe')
)
$ErrorActionPreference = 'Stop'
$sharedRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$native = Join-Path $sharedRoot 'art\pixelorama\senu\senu_shared_v6.pxo'
$atlas = Join-Path $sharedRoot 'assets\sprites\senu_shared_v6.png'
$log = Join-Path $sharedRoot 'qa\pixelorama_shared_v6_export.log'
function Invoke-SharedProcess([string]$Executable, [string[]]$Arguments) {
    $line = ($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $p = Start-Process -FilePath $Executable -ArgumentList $line -WorkingDirectory $sharedRoot -WindowStyle Hidden -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw "O processo terminou com código $($p.ExitCode)." }
}
try {
    $began = [DateTime]::UtcNow
    Write-Host 'Exportando o corpo compartilhado pelo Pixelorama...'
    Invoke-SharedProcess $PixeloramaPath @('--rendering-method','gl_compatibility','--log-file',$log,'--quit-after','6000','--max-fps','60','--','--export','--spritesheet','--json','--output',$atlas,$native)
    $outputFile = Get-Item -LiteralPath $atlas
    if ($outputFile.Length -eq 0 -or $outputFile.LastWriteTimeUtc -lt $began.AddSeconds(-2)) { throw 'O atlas não foi atualizado.' }
    if ([IO.File]::ReadAllText($log) -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') { throw "Erro na exportação: $log" }
    & $PythonPath (Join-Path $PSScriptRoot 'build_shared_senu_v6.py') --finalize
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos metadados do personagem.' }
    Invoke-SharedProcess $GodotPath @('--headless','--path',$sharedRoot,'--editor','--import','--quit')
    Invoke-SharedProcess $GodotPath @('--headless','--path',$sharedRoot,'--script','res://tools/pixelorama/import_shared_senu_v6.gd')
    Write-Host 'Senu compartilhado exportado e integrado.'
    exit 0
} catch { Write-Host $_.Exception.Message; exit 1 }
