param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$GodotExe = 'godot',
    [switch]$SkipExport
)

$ErrorActionPreference = 'Stop'
$webRoot = Join-Path $ProjectRoot 'build/web'
$packageRoot = Join-Path $ProjectRoot 'build/itch'
$zipPath = Join-Path $packageRoot 'californication-web.zip'

if (-not $SkipExport) {
    New-Item -ItemType Directory -Force -Path $webRoot | Out-Null
    $indexPath = Join-Path $webRoot 'index.html'
    $logPath = Join-Path $ProjectRoot 'build/task28_export.log'
    $arguments = "--headless --path `"$ProjectRoot`" --export-release Web `"$indexPath`" --log-file `"$logPath`""
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Godot Web export failed with exit code $($process.ExitCode)." }
}

if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) { throw 'Web export is missing root-level index.html.' }

$files = @(Get-ChildItem -LiteralPath $webRoot -Recurse -File)
$totalBytes = [int64]0
foreach ($file in $files) {
    $relative = $file.FullName.Substring($webRoot.Length + 1).Replace('\', '/')
    $totalBytes += $file.Length
    if ($file.Length -gt 200MB) { throw "File exceeds 200 MB: $relative" }
    if ($relative.Length -gt 240) { throw "Path exceeds 240 characters: $relative" }
    if ($relative -match '(^|/)(dev|tests|ref)(/|$)') { throw "Development/reference content leaked: $relative" }
}
if ($totalBytes -gt 500MB) { throw "Extracted Web package exceeds 500 MB: $totalBytes bytes" }

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $webRoot '*') -DestinationPath $zipPath -Force

$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
    foreach ($entry in $entries) {
        if ($entry.FullName -notmatch '^index\.[^/]+$') { throw "ZIP entry is not at archive root: $($entry.FullName)" }
    }
    if (-not ($entries.FullName -contains 'index.html')) { throw 'ZIP root does not contain index.html.' }
    Write-Output ("WEB_PACKAGE_PASS files={0} bytes={1} zip={2}" -f $entries.Count, $totalBytes, $zipPath)
}
finally { $archive.Dispose() }
