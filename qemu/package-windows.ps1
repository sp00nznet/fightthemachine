# Fight the Machine - Windows Package Builder
# Downloads QEMU, bundles VM image, and creates distributable ZIP
#
# Usage: .\package-windows.ps1 [-QemuVersion "8.2.0"] [-OutputDir "dist"]

param(
    [string]$QemuVersion = "8.2.0",
    [string]$OutputDir = "dist",
    [string]$VMImage = "qemu\fightthemachine.qcow2",
    [switch]$SkipQemuDownload
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$QemuUrl = "https://qemu.weilnetz.de/w64/qemu-w64-setup-$QemuVersion.exe"
$QemuDir = Join-Path $ProjectDir "qemu\qemu-win64"
$OutputPath = Join-Path $ProjectDir $OutputDir

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Fight the Machine - Windows Package Builder" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Download QEMU for Windows
if (-not $SkipQemuDownload) {
    Write-Host "[1/5] Downloading QEMU $QemuVersion for Windows..." -ForegroundColor Yellow

    $QemuInstaller = Join-Path $env:TEMP "qemu-setup.exe"

    if (-not (Test-Path $QemuInstaller)) {
        Write-Host "  Downloading from $QemuUrl..."
        Invoke-WebRequest -Uri $QemuUrl -OutFile $QemuInstaller -UseBasicParsing
    }

    # Extract QEMU (it's an NSIS installer, we can extract with 7-zip)
    Write-Host "  Extracting QEMU..."

    if (-not (Test-Path $QemuDir)) {
        New-Item -ItemType Directory -Path $QemuDir | Out-Null
    }

    # Try 7-zip first, fall back to running installer silently
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    if (Test-Path $7zipPath) {
        & $7zipPath x $QemuInstaller -o"$QemuDir" -y | Out-Null
    } else {
        Write-Host "  Note: 7-Zip not found, using installer extraction..."
        Start-Process -FilePath $QemuInstaller -ArgumentList "/S", "/D=$QemuDir" -Wait
    }
} else {
    Write-Host "[1/5] Skipping QEMU download (using existing)" -ForegroundColor Gray
}

# Verify VM image exists
Write-Host "[2/5] Verifying VM image..." -ForegroundColor Yellow
$VMImagePath = Join-Path $ProjectDir $VMImage

if (-not (Test-Path $VMImagePath)) {
    Write-Host "  ERROR: VM image not found at $VMImagePath" -ForegroundColor Red
    Write-Host "  Run build-vm-image.sh first to create the VM image" -ForegroundColor Red
    exit 1
}

$VMSize = (Get-Item $VMImagePath).Length / 1MB
Write-Host "  Found: $VMImagePath ($([math]::Round($VMSize, 1)) MB)" -ForegroundColor Green

# Build Win32 launcher
Write-Host "[3/5] Building Win32 launcher..." -ForegroundColor Yellow
$Win32Dir = Join-Path $ProjectDir "win32"
$BuildDir = Join-Path $Win32Dir "build"

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

Push-Location $BuildDir
try {
    cmake -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release -DUSE_QEMU=ON ..
    cmake --build . --config Release --parallel
} finally {
    Pop-Location
}

$LauncherExe = Join-Path $BuildDir "Release\fightthemachine.exe"
if (-not (Test-Path $LauncherExe)) {
    Write-Host "  ERROR: Build failed, launcher not found" -ForegroundColor Red
    exit 1
}

# Create package structure
Write-Host "[4/5] Creating package structure..." -ForegroundColor Yellow
$PackageDir = Join-Path $OutputPath "FightTheMachine-QEMU"

if (Test-Path $PackageDir) {
    Remove-Item -Recurse -Force $PackageDir
}

New-Item -ItemType Directory -Path $PackageDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $PackageDir "qemu") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $PackageDir "vm") | Out-Null

# Copy launcher
Copy-Item $LauncherExe (Join-Path $PackageDir "fightthemachine.exe")

# Copy WebView2 loader if exists
$WebView2Dll = Join-Path $BuildDir "Release\WebView2Loader.dll"
if (Test-Path $WebView2Dll) {
    Copy-Item $WebView2Dll $PackageDir
}

# Copy QEMU binaries (only what we need)
$QemuFiles = @(
    "qemu-system-x86_64.exe",
    "qemu-system-x86_64w.exe"  # Windows GUI version
)

$QemuBinDir = Join-Path $QemuDir "qemu"
if (-not (Test-Path $QemuBinDir)) {
    $QemuBinDir = $QemuDir  # Installer might extract directly
}

foreach ($file in $QemuFiles) {
    $src = Join-Path $QemuBinDir $file
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $PackageDir "qemu")
    }
}

# Copy all DLLs from QEMU directory
Get-ChildItem -Path $QemuBinDir -Filter "*.dll" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $PackageDir "qemu")
}

# Copy BIOS/firmware files
$FirmwareFiles = @("bios-256k.bin", "kvmvapic.bin", "vgabios-virtio.bin", "efi-virtio.rom")
foreach ($file in $FirmwareFiles) {
    $src = Join-Path $QemuBinDir "share\$file"
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $PackageDir "qemu")
    }
}

# Copy VM image
Copy-Item $VMImagePath (Join-Path $PackageDir "vm\fightthemachine.qcow2")

# Create README
$ReadmeContent = @"
Fight the Machine - QEMU Embedded Edition
==========================================

Kill processes as DOOM monsters!

This package includes a complete portable VM - no Docker required!

REQUIREMENTS:
- Windows 10 or later (64-bit)
- 4GB RAM minimum (8GB recommended)
- Hardware virtualization (Intel VT-x or AMD-V) recommended

USAGE:
1. Run fightthemachine.exe
2. Wait for the VM to boot (~10-30 seconds)
3. Play DOOM and kill process monsters!

CONTROLS:
- Arrow keys: Move
- Ctrl: Fire
- Space: Open doors
- F11: Toggle fullscreen
- ESC: Exit fullscreen

PERFORMANCE:
- Best: Windows with Hyper-V/WHPX enabled
- Good: Windows with Intel HAXM
- Slower: Software emulation (TCG)

To enable Hyper-V (recommended):
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

TROUBLESHOOTING:
- If the VM is slow, enable hardware virtualization in BIOS
- If WebView2 fails, install Microsoft Edge WebView2 Runtime
- Firewall may need to allow local connections on port 6080

Source: https://github.com/sp00nznet/fightthemachine
"@

$ReadmeContent | Out-File -FilePath (Join-Path $PackageDir "README.txt") -Encoding UTF8

# Create ZIP package
Write-Host "[5/5] Creating ZIP package..." -ForegroundColor Yellow
$ZipPath = Join-Path $OutputPath "FightTheMachine-QEMU-$((Get-Date).ToString('yyyyMMdd')).zip"

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath
}

Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

# Calculate sizes
$PackageSizeMB = (Get-Item $ZipPath).Length / 1MB

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Package Build Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Output: $ZipPath" -ForegroundColor White
Write-Host "Size: $([math]::Round($PackageSizeMB, 1)) MB" -ForegroundColor White
Write-Host ""
