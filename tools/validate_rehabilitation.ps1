param(
    [string]$GodotExe = 'godot',
    [switch]$Render,
    [switch]$Export
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Get-Command $GodotExe).Source
$logDirectory = Join-Path $projectDirectory 'build/rehabilitation'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $projectDirectory 'build/.gdignore') | Out-Null

function Invoke-GodotCheck([string]$Name, [string]$Arguments) {
    $logPath = Join-Path $logDirectory ($Name + '.log')
    $process = Start-Process -FilePath $enginePath -WorkingDirectory $projectDirectory -ArgumentList ($Arguments + ' --log-file "' + $logPath + '"') -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) {
        Stop-Process -Id $process.Id
        throw "Timed out: $Name"
    }
    $log = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
    if ($process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:|REHABILITATION_FAIL|PACK_CONTENT_FAIL') {
        Write-Output $log
        throw "Validation failed: $Name (exit $($process.ExitCode))"
    }
    Write-Output "PASS $Name"
}

Invoke-GodotCheck 'import' '--headless --editor --path . --import --quit'
Invoke-GodotCheck 'main' '--headless --path . --quit-after 90'
foreach ($index in 0..5) {
    $name = 'task_{0:D2}' -f $index
    # Godot engine arguments must precede the user-argument separator.
    $logPath = Join-Path $logDirectory ($name + '.log')
    $process = Start-Process -FilePath $enginePath -WorkingDirectory $projectDirectory -ArgumentList ('--headless --path . tests/cli/TestRunner.tscn --log-file "' + $logPath + '" -- --suite=' + $name) -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw "Timed out: $name" }
    $log = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
    if ($process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:') { Write-Output $log; throw "Validation failed: $name" }
    Write-Output "PASS $name"
}
foreach ($index in 6..27) {
    $name = 'task_{0:D2}' -f $index
    $scene = 'tests/cli/Task{0:D2}Test.tscn' -f $index
    Invoke-GodotCheck $name "--headless --path . $scene"
}
Invoke-GodotCheck 'production_flow_and_soaks' '--headless --path . tests/cli/RehabilitationTest.tscn'
if ($Render) {
    # Keep --render after all engine arguments.
    $renderLog = Join-Path $logDirectory 'render.log'
    $process = Start-Process -FilePath $enginePath -WorkingDirectory $projectDirectory -ArgumentList ('--path . --rendering-method gl_compatibility tests/cli/RehabilitationTest.tscn --log-file "' + $renderLog + '" -- --render') -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw 'Render validation timed out' }
    $log = Get-Content -LiteralPath $renderLog -Raw -Encoding UTF8
    if ($process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:|REHABILITATION_FAIL') { Write-Output $log; throw 'Render validation failed' }
    Write-Output 'PASS Compatibility renders at 960x720, 844x390, 360x640'
}
if ($Export) {
    & (Join-Path $PSScriptRoot 'package_web.ps1') -ProjectRoot $projectDirectory -GodotExe $enginePath
    $auditScript = Join-Path $projectDirectory 'tests/cli/ExportAudit.gd'
    Invoke-GodotCheck 'pack_content' ('--headless --path . --main-pack build/web/index.pck --script "' + $auditScript + '"')
}
