<#
.SYNOPSIS
    Package the native Windows build into a self-contained release ZIP.

.DESCRIPTION
    Produces dist/FightTheMachine-Native-<version>.zip containing the game, its
    runtime DLLs, the shareware DOOM IWAD (doom1.wad, v1.9) and the
    licence/source paperwork the GPL requires. Players with retail DOOM or
    DOOM II drop doom.wad / doom2.wad beside the exe and the engine prefers it.

    Runtime DLLs are discovered by walking the executable's real import table
    with objdump rather than from a hand-maintained list -- the hand-maintained
    one had drifted and was missing SDL_mixer's own dependencies, which meant a
    zip that ran on the build machine and died everywhere else.

.PARAMETER SkipBuild
    Package whatever is already in build/ instead of rebuilding first.

.EXAMPLE
    .\package.ps1
    .\package.ps1 -SkipBuild
#>
param(
    [switch]$SkipBuild,
    [string]$Msys2Root = "C:\msys64"
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 wraps a native program's stderr in ErrorRecords, so a
# harmless compiler warning becomes a terminating error under -EA Stop. Run
# native tools with that relaxed and judge them by their exit code instead.
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Block, [string]$What = "command")
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $Block } finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit code $LASTEXITCODE)" }
}

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = (Resolve-Path "$scriptDir\..\..").Path
$buildDir   = "$scriptDir\build"
$mingwBin   = "$Msys2Root\mingw64\bin"
$distDir    = "$projectDir\dist"
$stageDir   = "$distDir\FightTheMachine-Native"

if (-not (Test-Path "$mingwBin\objdump.exe")) {
    throw "MSYS2 MinGW64 not found at $mingwBin. Install MSYS2 or pass -Msys2Root."
}

# ---------------------------------------------------------------- build ------
if (-not $SkipBuild) {
    Write-Host "==> Building..." -ForegroundColor Cyan
    $bash = "$Msys2Root\usr\bin\bash.exe"
    $unixProject = ($scriptDir -replace '\\', '/') -replace '^([A-Za-z]):', '/$1'
    Invoke-Native -What "Build" -Block {
        & $bash --login -c "export MSYSTEM=MINGW64; source /etc/profile; cd '$unixProject' && ./build-windows.sh --clean"
    }
}

$exe = "$buildDir\fightthemachine.exe"
if (-not (Test-Path $exe)) { throw "$exe not found - build first (omit -SkipBuild)" }

# ---------------------------------------------------------------- stage ------
Write-Host "==> Staging package..." -ForegroundColor Cyan
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

Copy-Item $exe $stageDir

# Walk the import table transitively; bundle anything that lives in MinGW's bin
# (i.e. is not a Windows system DLL).
function Get-BundledDlls {
    param([string]$Root)
    $seen = @{}
    $found = New-Object System.Collections.Generic.List[string]
    $queue = New-Object System.Collections.Generic.Queue[string]
    $queue.Enqueue($Root)
    while ($queue.Count -gt 0) {
        $file = $queue.Dequeue()
        $prev = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $imports = & "$mingwBin\objdump.exe" -p $file |
            Select-String 'DLL Name:\s*(\S+)' |
            ForEach-Object { $_.Matches[0].Groups[1].Value }
        $ErrorActionPreference = $prev
        foreach ($dll in $imports) {
            $key = $dll.ToLower()
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true
            $path = Join-Path $mingwBin $dll
            if (Test-Path $path) { $found.Add($path); $queue.Enqueue($path) }
        }
    }
    return $found
}

$dlls = Get-BundledDlls -Root $exe
Write-Host "    bundling $($dlls.Count) runtime DLLs"
foreach ($d in $dlls) { Copy-Item $d $stageDir }

# ------------------------------------------------------------- game data ----
# psdoom-ng resolves these with D_FindWADByName, which only looks beside the
# executable - they must be flat, not in a wad/ subdirectory.
Copy-Item "$projectDir\wad\psdoom1.wad" $stageDir
Copy-Item "$projectDir\wad\psdoom2.wad" $stageDir

# Shareware v1.9. Never committed (third-party asset); fetched at package time
# and pinned by md5 so a bad mirror can't slip a modified IWAD into a release.
$sharewareMd5 = "f0cefca49926d00903cf57551d901abe"
$sharewareWad = "$distDir\doom1.wad"
if (-not (Test-Path $sharewareWad)) {
    Write-Host "==> Downloading shareware doom1.wad..." -ForegroundColor Cyan
    $url = "https://github.com/Akbar30Bill/DOOM_wads/raw/master/doom1.wad"
    Invoke-Native -What "doom1.wad download" -Block {
        & curl.exe -L -o $sharewareWad $url --retry 3 --retry-delay 5 --progress-bar
    }
}
$md5 = (Get-FileHash $sharewareWad -Algorithm MD5).Hash.ToLower()
if ($md5 -ne $sharewareMd5) {
    Remove-Item $sharewareWad
    throw "doom1.wad md5 $md5 is not the v1.9 shareware release ($sharewareMd5)"
}
Copy-Item $sharewareWad $stageDir

# ------------------------------------------------------------- paperwork ----
Copy-Item "$scriptDir\fightthemachine.cfg" $stageDir
Copy-Item "$scriptDir\run.bat" $stageDir
Copy-Item "$scriptDir\README.md" "$stageDir\README.md"
Copy-Item "$projectDir\LICENSE" "$stageDir\LICENSE.txt"

$commit = (& git -C $projectDir rev-parse HEAD 2>$null)
if (-not $commit) { $commit = "unknown" }
$describe = (& git -C $projectDir describe --tags --always 2>$null)
if (-not $describe) { $describe = $commit.Substring(0, [Math]::Min(7, $commit.Length)) }

@"
Fight the Machine - Source Code
===============================

Fight the Machine is free software licensed under the GNU General Public
License version 2. See LICENSE.txt for the full terms.

The complete corresponding source code for this binary, including the build
scripts used to produce it, is published at:

    https://github.com/sp00nznet/fightthemachine

This build was made from commit:

    $commit

You may obtain, modify and redistribute that source under the terms of the
GPL v2. If the repository above is ever unavailable, the authors will supply
the complete source on request for no more than the cost of distribution.

Third-party components
----------------------

psDoom-ng (GPL v2)      https://github.com/orsonteodoro/psdoom-ng
Chocolate Doom (GPL v2) https://www.chocolate-doom.org/
psDoom (GPL v2)         http://psdoom.sourceforge.net/
DOOM engine (GPL v2)    https://github.com/id-Software/DOOM

The bundled psdoom1.wad and psdoom2.wad are the psDoom level data, modified
for this release: their TEXTURE1/TEXTURE2/PNAMES lumps were removed so the
levels render against any IWAD, and E1M1's few registered-only textures and
weapons were swapped for shareware ones. See patches/portable-psdoom-wad.py
in the source repository.

Game assets
-----------

doom1.wad is the unmodified shareware release of DOOM v1.9 by id Software,
included as freely distributable shareware. For the full game, buy DOOM or
DOOM II and put doom.wad or doom2.wad next to fightthemachine.exe.
"@ | Set-Content "$stageDir\SOURCE.txt" -Encoding utf8

# ------------------------------------------------------------------- zip ----
$zipPath = "$distDir\FightTheMachine-Native-$describe.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-Host "==> Compressing..." -ForegroundColor Cyan
Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

$sizeMb = [Math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host ""
Write-Host "Package: $zipPath ($sizeMb MB)" -ForegroundColor Green
Get-ChildItem $stageDir | Select-Object Name, @{n = 'KB'; e = { [Math]::Round($_.Length / 1KB) } } | Format-Table -AutoSize
