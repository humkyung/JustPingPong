# build.ps1 — Package JustPingPong as a standalone Windows .exe

$ErrorActionPreference = "Stop"

$ProjectName = "JustPingPong"
$LoveDir     = "C:\Program Files\LOVE"
$RootDir     = $PSScriptRoot
$DistDir     = Join-Path $RootDir "dist"
$BuildDir    = Join-Path $DistDir $ProjectName
$LoveFile    = Join-Path $RootDir "$ProjectName.love"
$ZipFile     = Join-Path $DistDir "$ProjectName-win64.zip"
$SourceFiles = @("main.lua", "hit.wav", "intro.png")

Write-Host "[1/5] Checking environment..."
$LoveExe = Join-Path $LoveDir "love.exe"
if (-not (Test-Path $LoveExe)) {
    Write-Error "LOVE not found at $LoveDir. Install from https://love2d.org or edit `$LoveDir in this script."
    exit 1
}
if (-not (Test-Path (Join-Path $RootDir "main.lua"))) {
    Write-Error "main.lua not found in $RootDir."
    exit 1
}

Write-Host "[2/5] Cleaning dist directory..."
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

Write-Host "[3/5] Creating $ProjectName.love..."
if (Test-Path $LoveFile) { Remove-Item $LoveFile -Force }
# .love files require sources at the zip ROOT (not nested in a subfolder), so use the
# .NET API directly — Compress-Archive would preserve the source directory structure.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($LoveFile, "Create")
try {
    foreach ($name in $SourceFiles) {
        $path = Join-Path $RootDir $name
        if (Test-Path $path) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $path, $name) | Out-Null
            Write-Host "  + $name"
        } else {
            Write-Host "  - $name (skipped, optional)"
        }
    }
} finally {
    $zip.Dispose()
}

Write-Host "[4/5] Building $ProjectName.exe and bundling runtime..."
$OutExe = Join-Path $BuildDir "$ProjectName.exe"
$loveBytes = [System.IO.File]::ReadAllBytes($LoveExe)
$gameBytes = [System.IO.File]::ReadAllBytes($LoveFile)
$combined  = New-Object byte[] ($loveBytes.Length + $gameBytes.Length)
[Array]::Copy($loveBytes, 0, $combined, 0, $loveBytes.Length)
[Array]::Copy($gameBytes, 0, $combined, $loveBytes.Length, $gameBytes.Length)
[System.IO.File]::WriteAllBytes($OutExe, $combined)

Get-ChildItem -Path $LoveDir -File | Where-Object {
    $_.Name -ne "love.exe" -and ($_.Extension -eq ".dll" -or $_.Extension -eq ".txt")
} | ForEach-Object {
    Copy-Item $_.FullName -Destination $BuildDir
}

Remove-Item $LoveFile -Force

Write-Host "[5/5] Creating zip archive..."
if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipFile

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "  Folder: $BuildDir"
Write-Host "  Zip:    $ZipFile"
