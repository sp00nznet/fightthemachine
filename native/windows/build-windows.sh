#!/bin/bash
# ==============================================================================
# Fight the Machine - Native Windows Build Script
# ==============================================================================
#
# This script builds Fight the Machine as a native Windows executable that can
# enumerate and kill REAL Windows processes (based on psDoom-ng engine).
#
# Prerequisites (run in MSYS2 MINGW64 terminal):
#   pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
#             mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \
#             mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng \
#             git make
#
# Usage:
#   ./build-windows.sh [OPTIONS]
#
# Options:
#   --clean         Clean build directory before building
#   --unsafe        Disable safe mode (allow killing all processes)
#   --release       Build release version (default)
#   --debug         Build debug version
#   --help          Show this help message
#
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BUILD_DIR="$SCRIPT_DIR/build"
PSDOOM_SRC_DIR="$PROJECT_DIR/psdoom-ng-src/trunk/src"

# Default options
CLEAN=0
SAFE_MODE=ON
BUILD_TYPE=Release

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=1
            shift
            ;;
        --unsafe)
            SAFE_MODE=OFF
            shift
            ;;
        --release)
            BUILD_TYPE=Release
            shift
            ;;
        --debug)
            BUILD_TYPE=Debug
            shift
            ;;
        --help|-h)
            head -35 "$0" | tail -30
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Fight the Machine - Native Windows Build               ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  This builds a NATIVE Windows executable that kills          ║${NC}"
echo -e "${GREEN}║  REAL Windows processes when you kill DOOM monsters!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we're on Windows/MSYS2
if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "mingw"* ]] && [[ "$OSTYPE" != "cygwin" ]]; then
    echo -e "${YELLOW}WARNING: This script is designed for MSYS2/MinGW on Windows.${NC}"
    echo -e "${YELLOW}         Cross-compilation from Linux may require additional setup.${NC}"
    echo ""
fi

# Check for psdoom-ng source
if [[ ! -d "$PSDOOM_SRC_DIR" ]]; then
    echo -e "${YELLOW}psdoom-ng source not found. Cloning...${NC}"
    cd "$PROJECT_DIR"
    git clone --depth 1 https://github.com/orsonteodoro/psdoom-ng.git psdoom-ng-src
fi

# Apply the sudo cheat patch if not already applied
ST_STUFF="$PROJECT_DIR/psdoom-ng-src/trunk/src/doom/st_stuff.c"
if ! grep -q "cheat_sudo" "$ST_STUFF" 2>/dev/null; then
    echo -e "${YELLOW}Applying sudo cheat patch...${NC}"
    if [[ -f "$PROJECT_DIR/patches/add-sudo-cheat.sh" ]]; then
        bash "$PROJECT_DIR/patches/add-sudo-cheat.sh" "$ST_STUFF"
    fi
fi

# Verify dependencies
echo "[1/5] Checking dependencies..."
MISSING_DEPS=0

check_dep() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}  Missing: $1${NC}"
        MISSING_DEPS=1
    else
        echo -e "${GREEN}  Found: $1${NC}"
    fi
}

check_dep cmake
check_dep make
check_dep gcc

# Check for SDL libraries
if [[ -n "$MSYSTEM" ]]; then
    # MSYS2 - check for packages
    if ! pacman -Q mingw-w64-x86_64-SDL &>/dev/null; then
        echo -e "${RED}  Missing: mingw-w64-x86_64-SDL${NC}"
        MISSING_DEPS=1
    else
        echo -e "${GREEN}  Found: SDL${NC}"
    fi
    if ! pacman -Q mingw-w64-x86_64-SDL_mixer &>/dev/null; then
        echo -e "${RED}  Missing: mingw-w64-x86_64-SDL_mixer${NC}"
        MISSING_DEPS=1
    else
        echo -e "${GREEN}  Found: SDL_mixer${NC}"
    fi
fi

if [[ $MISSING_DEPS -eq 1 ]]; then
    echo ""
    echo -e "${RED}Please install missing dependencies:${NC}"
    echo "  pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \\"
    echo "            mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \\"
    echo "            mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng \\"
    echo "            git make"
    exit 1
fi

# Clean if requested
if [[ $CLEAN -eq 1 ]]; then
    echo "[2/5] Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure
echo "[3/5] Configuring with CMake..."
echo "  Build type: $BUILD_TYPE"
echo "  Safe mode: $SAFE_MODE"

CMAKE_GENERATOR="Unix Makefiles"
if [[ -n "$MSYSTEM" ]]; then
    CMAKE_GENERATOR="MSYS Makefiles"
fi

cmake -G "$CMAKE_GENERATOR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DENABLE_SAFE_MODE="$SAFE_MODE" \
    -DPSDOOM_SRC_DIR="$PSDOOM_SRC_DIR" \
    "$SCRIPT_DIR"

# Build
echo ""
echo "[4/5] Building..."
cmake --build . --parallel

# Package
echo ""
echo "[5/5] Packaging..."
if command -v cpack &> /dev/null; then
    cpack -C "$BUILD_TYPE" -G ZIP 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Build Complete!                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Output directory: $BUILD_DIR"
echo ""

# List built files
if [[ -f "$BUILD_DIR/fightthemachine.exe" ]]; then
    echo -e "${GREEN}Built: fightthemachine.exe${NC}"
    ls -lh "$BUILD_DIR/fightthemachine.exe"
    echo ""
    echo "To run:"
    echo "  cd $BUILD_DIR"
    echo "  ./fightthemachine.exe -iwad DOOM.WAD"
    echo ""
    if [[ "$SAFE_MODE" == "ON" ]]; then
        echo -e "${YELLOW}NOTE: Safe mode is ENABLED - only safe processes can be killed.${NC}"
        echo "      Use --unsafe flag to disable safe mode."
    else
        echo -e "${RED}WARNING: Safe mode is DISABLED - all processes can be killed!${NC}"
    fi
fi

echo ""
