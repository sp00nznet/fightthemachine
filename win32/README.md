# Fight the Machine - Win32 Native Client

A native Windows application that provides a seamless interface to the Fight the Machine game running in Docker.

## Features

- Native Windows 10/11 application
- Embedded WebView2 browser for noVNC display
- Automatic Docker container management
- Fullscreen support (F11)
- DPI-aware and modern Windows styling

## Requirements

- Windows 10 version 1809 or later
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) (usually pre-installed on Windows 10/11)
- Visual Studio 2019/2022 with C++ workload (for building)

## Building

### Quick Build

```batch
cd win32
build.bat release
```

### Manual Build with CMake

```powershell
cd win32
mkdir build
cd build
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
```

### Build Options

```batch
build.bat clean          # Clean build directory
build.bat release        # Build Release version
build.bat package        # Build and create installer
build.bat clean release  # Clean then build Release
```

## Usage

1. Ensure Docker Desktop is running
2. Run `fightthemachine.exe`
3. Wait for the loading screen (container is starting)
4. Play DOOM!

## Controls

| Key | Action |
|-----|--------|
| Arrow Keys | Move |
| Ctrl | Fire |
| Space | Open doors/Use |
| Alt | Strafe |
| F11 | Toggle fullscreen |
| ESC | Exit fullscreen |

## Architecture

```
fightthemachine.exe
    │
    ├── WebView2 (Embedded Edge browser)
    │       │
    │       └── noVNC (HTML5 VNC client)
    │               │
    │               └── http://localhost:6080
    │
    └── Docker Management
            │
            └── fightthemachine container
                    │
                    ├── x11vnc (VNC server)
                    ├── Xvfb (Virtual display)
                    └── psDoom-ng (Game engine)
```

## Files

| File | Description |
|------|-------------|
| `main.cpp` | Main application source |
| `resource.h` | Resource identifiers |
| `app.rc` | Resource script (icon, version info) |
| `app.manifest` | Application manifest (DPI, styling) |
| `CMakeLists.txt` | CMake build configuration |
| `build.ps1` | PowerShell build script |
| `build.bat` | Batch build wrapper |

## Dependencies

- [Microsoft WebView2](https://developer.microsoft.com/microsoft-edge/webview2/) - Embedded browser
- [Windows Implementation Libraries (WIL)](https://github.com/microsoft/wil) - COM helpers

Both dependencies are automatically downloaded via CMake FetchContent.

## Troubleshooting

### "Docker Desktop is not running"
Start Docker Desktop and wait for it to fully initialize before running the application.

### "Failed to initialize WebView2"
Install the [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

### Container fails to start
Check Docker Desktop logs and ensure you have enough disk space and memory allocated.

### Black screen in game
The container may still be initializing. Wait a few more seconds for psDoom-ng to start.
