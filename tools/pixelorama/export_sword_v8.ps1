param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'),
    [string]$PythonPath = (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe')
)
$ErrorActionPreference = 'Stop'
$cutRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$native = Join-Path $cutRoot 'art\pixelorama\senu\senu_sword_v8.pxo'
$atlas = Join-Path $cutRoot 'assets\sprites\senu_sword_v8.png'
$log = Join-Path $cutRoot 'qa\pixelorama_sword_v8_export.log'
try {
    $argsList = @('--rendering-method','gl_compatibility','--log-file',$log,'--quit-after','1800','--max-fps','60','--','--export','--spritesheet','--json','--output',$atlas,$native)
    $line = ($argsList | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $process = Start-Process -FilePath $PixeloramaPath -ArgumentList $line -WorkingDirectory $cutRoot -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw 'Falha ao exportar os cortes no Pixelorama.' }
    & $PythonPath (Join-Path $PSScriptRoot 'build_sword_v8.py') --finalize
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos metadados dos cortes.' }
    & $GodotPath --headless --path $cutRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Falha na importação no Godot.' }
    Write-Host 'Cortes da espada exportados e integrados.'
    exit 0
} catch { Write-Host $_.Exception.Message; exit 1 }
