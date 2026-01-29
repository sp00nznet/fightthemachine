#!/bin/bash
# Fight the Machine - Native Windows Build Script for MSYS2
#
# This script builds the native Windows port of psDoom-ng using MSYS2.
#
# Prerequisites:
#   1. Install MSYS2 from https://www.msys2.org/
#   2. Open MSYS2 MINGW64 terminal
#   3. Install dependencies:
#      pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
#                mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \
#                mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng \
#                git autoconf automake libtool make
#
# Usage: ./build-msys2.sh [--with-psdoom] [--clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"

BUILD_PSDOOM=0
CLEAN=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-psdoom)
            BUILD_PSDOOM=1
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Fight the Machine - Native Windows Build"
echo "=========================================="
echo ""

# Set up MINGW64 environment if not already set
if [[ -z "$MSYSTEM" ]] || [[ "$MSYSTEM" != "MINGW64" ]]; then
    echo "Setting up MINGW64 environment..."
    export MSYSTEM=MINGW64
    # Add MINGW64 bin directories to PATH
    if [[ -d "/mingw64/bin" ]]; then
        export PATH="/mingw64/bin:$PATH"
    elif [[ -d "/c/tools/msys64/mingw64/bin" ]]; then
        export PATH="/c/tools/msys64/mingw64/bin:$PATH"
    elif [[ -d "/c/msys64/mingw64/bin" ]]; then
        export PATH="/c/msys64/mingw64/bin:$PATH"
    fi
fi

# Verify cmake is available
if ! command -v cmake &> /dev/null; then
    echo "ERROR: cmake not found in PATH"
    echo "Please install: pacman -S mingw-w64-x86_64-cmake"
    echo "Current PATH: $PATH"
    exit 1
fi

echo "Using cmake: $(which cmake)"

# Clean if requested
if [[ $CLEAN -eq 1 ]]; then
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[1/3] Configuring with CMake..."
cmake -G "MSYS Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_RESPAWNER=ON \
    -DBUILD_TEST_APP=ON \
    "$SCRIPT_DIR"

echo ""
echo "[2/3] Building..."
cmake --build . --config Release --parallel

echo ""
echo "[3/3] Packaging..."
cpack -C Release -G ZIP

# Build psDoom-ng if requested
if [[ $BUILD_PSDOOM -eq 1 ]]; then
    echo ""
    echo "[EXTRA] Building psDoom-ng with Windows process support..."

    PSDOOM_DIR="$BUILD_DIR/psdoom-ng"

    if [[ ! -d "$PSDOOM_DIR" ]]; then
        echo "Cloning psdoom-ng..."
        git clone --depth 1 https://github.com/orsonteodoro/psdoom-ng.git "$PSDOOM_DIR"
    fi

    cd "$PSDOOM_DIR/trunk"

    # Apply the Windows process patch
    # (This would need to be implemented - replacing the Linux process code)
    echo "NOTE: psDoom-ng Windows integration requires manual patching"
    echo "      See native/README.md for instructions"
fi

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Output files in: $BUILD_DIR"
ls -la "$BUILD_DIR"/*.exe 2>/dev/null || echo "(no executables found)"
ls -la "$BUILD_DIR"/*.zip 2>/dev/null || echo "(no packages found)"
echo ""
