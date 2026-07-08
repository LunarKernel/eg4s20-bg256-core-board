$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceDir = Join-Path $repo 'AltiumProject\EG4S20_SummerProject'
$libSource = Join-Path $repo 'AltiumProject\CompatLibrary\EG4S20BG256.SCHLIB'
$workRoot = Join-Path $env:TEMP 'eg4s20_altium_a0'
$stageDir = Join-Path $workRoot 'EG4S20_SummerProject'
$libStageDir = Join-Path $workRoot 'CompatLibrary'

New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
New-Item -ItemType Directory -Force -Path $libStageDir | Out-Null

$sheets = @(
    '02_FPGA_Clock_Flash.SchDoc',
    '03_USB_JTAG.SchDoc',
    '04_UserIO.SchDoc',
    '05_Power.SchDoc'
)

foreach ($sheet in $sheets) {
    $source = Join-Path $sourceDir $sheet
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing source sheet: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $stageDir $sheet) -Force
}

if (-not (Test-Path -LiteralPath $libSource)) {
    throw "Missing schematic library: $libSource"
}
$libTarget = Join-Path $libStageDir 'EG4S20BG256.SCHLIB'
Copy-Item -LiteralPath $libSource -Destination $libTarget -Force

$pasSource = Join-Path $repo 'AltiumProject\CreateA0NativeFromSheets.pas'
$prjSource = Join-Path $repo 'AltiumProject\CreateA0NativeFromSheets.PrjScr'
$pasTarget = Join-Path $workRoot 'CreateA0NativeFromSheets.pas'
$prjTarget = Join-Path $workRoot 'CreateA0NativeFromSheets.PrjScr'
$outSch = Join-Path $stageDir 'EG4S20BG256_CoreBoard_A0_NATIVE.SchDoc'

$pas = Get-Content -LiteralPath $pasSource -Raw
$baseDir = $stageDir.TrimEnd('\') + '\'
$pas = $pas -replace "BASE_DIR = '[^']*';", "BASE_DIR = '$baseDir';"
$pas = $pas -replace "LIB_PATH = '[^']*';", "LIB_PATH = '$libTarget';"
$pas = $pas -replace "OUT_SCH = '[^']*';", "OUT_SCH = '$outSch';"
Set-Content -LiteralPath $pasTarget -Value $pas -Encoding ASCII
Copy-Item -LiteralPath $prjSource -Destination $prjTarget -Force

Write-Host "Prepared: $workRoot"
Write-Host "Open in Altium: $prjTarget"
Write-Host "Output: $outSch"
