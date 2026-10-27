param(
    [string]$PixeloramaPath = (Join-Path $env:USERPROFILE 'Downloads\Pixelorama-Windows-64bit\Pixelorama.exe'),
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'),
    [switch]$Motion,
    [switch]$Port
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$nativeProject = Join-Path $projectRoot 'art\pixelorama\senu\senu_v4.pxo'
$atlasPath = Join-Path $projectRoot 'assets\sprites\senu_v4.png'
$metadataPath = Join-Path $projectRoot 'assets\sprites\senu_v4.json'
$qaDirectory = Join-Path $projectRoot 'qa'
$exportLog = Join-Path $qaDirectory 'pixelorama_senu_export.log'
if ($Motion) {
    $nativeProject = Join-Path $projectRoot 'art\pixelorama\senu\senu_motion_v5.pxo'
    $atlasPath = Join-Path $projectRoot 'assets\sprites\senu_motion_v5.png'
    $metadataPath = Join-Path $projectRoot 'assets\sprites\senu_motion_v5.json'
    $exportLog = Join-Path $qaDirectory 'pixelorama_motion_v5_export.log'
}
if ($Port) {
    $nativeProject = Join-Path $projectRoot 'art\pixelorama\port_v6\port_art_v6.pxo'
    $atlasPath = Join-Path $projectRoot 'assets\world\port_art_v6.png'
    $metadataPath = Join-Path $projectRoot 'assets\world\port_art_v6.json'
    $exportLog = Join-Path $qaDirectory 'pixelorama_port_v6_export.log'
}

function Quote-NativeArgument([string]$Value) {
    # Windows CommandLineToArgvW escaping, including paths ending in a slash.
    if ($Value -notmatch '[\s"]') { return $Value }
    $quoted = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
    return '"' + $quoted + '"'
}

function Invoke-CheckedProcess([string]$Executable, [string[]]$Arguments, [string]$Label) {
    $argumentLine = ($Arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' '
    $process = Start-Process -FilePath $Executable -ArgumentList $argumentLine -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "$Label terminou com código $($process.ExitCode)." }
}

try {
    foreach ($required in @($PixeloramaPath, $GodotPath, $nativeProject)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Arquivo necessário não encontrado: $required" }
    }
    [IO.Directory]::CreateDirectory($qaDirectory) | Out-Null
    $startedAt = [DateTime]::UtcNow
    Write-Host 'Exportando as artes salvas pelo Pixelorama...'
    $frameLimit = if ($Port) { '1800' } else { '6000' }
    $pixeloramaArguments = @(
        '--rendering-method', 'gl_compatibility', '--log-file', $exportLog,
        '--quit-after', $frameLimit, '--max-fps', '60', '--', '--export', '--spritesheet', '--json',
        '--output', $atlasPath, $nativeProject
    )
    Invoke-CheckedProcess $PixeloramaPath $pixeloramaArguments 'Pixelorama'
    foreach ($exported in @($atlasPath, $metadataPath)) {
        if (-not (Test-Path -LiteralPath $exported -PathType Leaf)) { throw "O Pixelorama não gerou: $exported" }
        $file = Get-Item -LiteralPath $exported
        if ($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $startedAt.AddSeconds(-2)) {
            throw "O arquivo não foi atualizado nesta exportação: $exported"
        }
    }
    if (-not (Test-Path -LiteralPath $exportLog -PathType Leaf)) { throw 'O Pixelorama não criou o registro de exportação.' }
    $logText = [IO.File]::ReadAllText($exportLog)
    if ($logText -match '(?im)^\s*(?:SCRIPT ERROR|ERROR):') {
        throw "O Pixelorama registrou um erro. Consulte $exportLog"
    }
    Write-Host 'Importando o atlas e atualizando as animações no Godot...'
    Invoke-CheckedProcess $GodotPath @('--headless', '--path', $projectRoot, '--editor', '--import', '--quit') 'Importação do Godot'
    $importScript = if ($Port) { 'res://tools/pixelorama/import_port_art_v6.gd' } else { 'res://tools/pixelorama/import_pixelorama_export.gd' }
    $importArguments = @('--headless', '--path', $projectRoot, '--script', $importScript)
    if ($Motion) { $importArguments += @('--', '--motion-v5') }
    Invoke-CheckedProcess $GodotPath $importArguments 'Atualização das animações'
    Write-Host 'Concluído. Feche uma partida antiga e abra JOGAR.cmd para testar.'
    exit 0
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
