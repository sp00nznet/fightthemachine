# Fight the Machine - Win32 Build Script
# Builds the native Windows client using CMake and MSVC

param(
    [switch]$Clean,
    [switch]$Release,
    [switch]$Package
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = Join-Path $ScriptDir "build"
$BuildType = if ($Release) { "Release" } else { "Debug" }

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Fight the Machine - Win32 Build" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check for required tools
Write-Host "[*] Checking prerequisites..." -ForegroundColor Yellow

# Check for CMake
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake) {
    Write-Host "[!] CMake not found. Please install CMake and add to PATH." -ForegroundColor Red
    Write-Host "    Download: https://cmake.org/download/" -ForegroundColor Gray
    exit 1
}
Write-Host "    CMake: $($cmake.Source)" -ForegroundColor Green

# Check for Visual Studio / MSVC
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -latest -property installationPath
    if ($vsPath) {
        Write-Host "    Visual Studio: $vsPath" -ForegroundColor Green
    }
} else {
    Write-Host "[!] Visual Studio not found. Please install Visual Studio 2019 or later." -ForegroundColor Red
    Write-Host "    Download: https://visualstudio.microsoft.com/" -ForegroundColor Gray
    exit 1
}

# Clean build if requested
if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "[*] Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $BuildDir
}

# Create build directory
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

# Configure with CMake
Write-Host ""
Write-Host "[*] Configuring with CMake..." -ForegroundColor Yellow
Push-Location $BuildDir
try {
    & cmake -G "Visual Studio 17 2022" -A x64 `
        -DCMAKE_BUILD_TYPE=$BuildType `
        ..

    if ($LASTEXITCODE -ne 0) {
        throw "CMake configuration failed"
    }

    # Build
    Write-Host ""
    Write-Host "[*] Building ($BuildType)..." -ForegroundColor Yellow
    & cmake --build . --config $BuildType --parallel

    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }

    # Package if requested
    if ($Package) {
        Write-Host ""
        Write-Host "[*] Creating package..." -ForegroundColor Yellow
        & cpack -C $BuildType

        if ($LASTEXITCODE -ne 0) {
            throw "Packaging failed"
        }
    }

    Write-Host ""
    Write-Host "====================================" -ForegroundColor Green
    Write-Host "  Build completed successfully!" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output: $BuildDir\$BuildType\fightthemachine.exe" -ForegroundColor Cyan

} finally {
    Pop-Location
}
