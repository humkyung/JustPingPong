# build.ps1 — Package JustPingPong as a standalone Windows .exe

$ErrorActionPreference = "Stop"

$ProjectName = "JustPingPong"
$LoveDir     = "C:\Program Files\LOVE"
$EnigmaDir   = "C:\Program Files (x86)\Enigma Virtual Box"
$RootDir     = $PSScriptRoot
$DistDir     = Join-Path $RootDir "dist"
$BuildDir    = Join-Path $DistDir $ProjectName
$LoveFile    = Join-Path $RootDir "$ProjectName.love"
$ZipFile     = Join-Path $DistDir "$ProjectName-win64.zip"
$SingleExe   = Join-Path $DistDir "$ProjectName-single.exe"
$EvbFile     = Join-Path $DistDir "$ProjectName.evb"
$SourceFiles = @("main.lua", "hit.wav", "intro.png")

Write-Host "[1/6] Checking environment..."
$LoveExe = Join-Path $LoveDir "love.exe"
if (-not (Test-Path $LoveExe)) {
    Write-Error "LOVE not found at $LoveDir. Install from https://love2d.org or edit `$LoveDir in this script."
    exit 1
}
if (-not (Test-Path (Join-Path $RootDir "main.lua"))) {
    Write-Error "main.lua not found in $RootDir."
    exit 1
}

Write-Host "[2/6] Cleaning dist directory..."
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

Write-Host "[3/6] Creating $ProjectName.love..."
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

Write-Host "[4/6] Building $ProjectName.exe and bundling runtime..."
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

Write-Host "[5/6] Creating zip archive..."
if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipFile

Write-Host "[6/6] Packing into single .exe with Enigma Virtual Box..."
$EnigmaConsole = Join-Path $EnigmaDir "enigmavbconsole.exe"
if (-not (Test-Path $EnigmaConsole)) {
    Write-Warning "Enigma Virtual Box not found at $EnigmaDir. Skipping single-exe step."
    Write-Warning "Install from https://enigmaprotector.com/en/downloads.html or edit `$EnigmaDir."
} else {
    if (Test-Path $SingleExe) { Remove-Item $SingleExe -Force }
    if (Test-Path $EvbFile)   { Remove-Item $EvbFile   -Force }

    $InputExe  = Join-Path $BuildDir "$ProjectName.exe"
    $SideFiles = Get-ChildItem -Path $BuildDir -File | Where-Object { $_.Name -ne "$ProjectName.exe" }

    $filesXml = ""
    foreach ($f in $SideFiles) {
        $filesXml += @"
          <File>
            <Type>2</Type>
            <Name>$($f.Name)</Name>
            <File>$($f.FullName)</File>
            <Action>0</Action>
            <OverwriteDateTime>false</OverwriteDateTime>
            <OverwriteAttributes>false</OverwriteAttributes>
            <PassCommandLine>false</PassCommandLine>
          </File>

"@
    }

    $evbContent = @"
<>
  <InputFile>$InputExe</InputFile>
  <OutputFile>$SingleExe</OutputFile>
  <Files>
    <Enabled>true</Enabled>
    <DeleteExtractedOnExit>false</DeleteExtractedOnExit>
    <CompressFiles>true</CompressFiles>
    <Files>
      <File>
        <Type>3</Type>
        <Name>%DEFAULT FOLDER%</Name>
        <Files>
$filesXml        </Files>
      </File>
    </Files>
  </Files>
  <Registries>
    <Enabled>false</Enabled>
    <Registries />
  </Registries>
  <Packages>
    <Enabled>false</Enabled>
    <Packages />
  </Packages>
  <Options>
    <ShareVirtualSystem>false</ShareVirtualSystem>
    <MapExecutableWithTemporaryFile>false</MapExecutableWithTemporaryFile>
    <AllowRunningOfVirtualExeFiles>true</AllowRunningOfVirtualExeFiles>
  </Options>
</>
"@

    Set-Content -Path $EvbFile -Value $evbContent -Encoding UTF8
    & $EnigmaConsole $EvbFile | Out-Host
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $SingleExe)) {
        Write-Warning "Enigma Virtual Box failed to produce $SingleExe (exit $LASTEXITCODE)."
    }
    Remove-Item $EvbFile -Force
}

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "  Folder:     $BuildDir"
Write-Host "  Zip:        $ZipFile"
if (Test-Path $SingleExe) {
    Write-Host "  Single exe: $SingleExe"
}
