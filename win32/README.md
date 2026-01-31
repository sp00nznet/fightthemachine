# Fight the Machine - Win32 QEMU Client

**Native Windows app that runs psDoom in a QEMU virtual machine.**

```
┌──────────────────────────────────────────────────────────────────┐
│                      WINDOWS HOST                                 │
│                                                                   │
│  fightthemachine.exe                                             │
│        │                                                          │
│        └── WebView2 ──▶ QEMU VM ──▶ psDoom-ng                    │
│                              │                                    │
│                              ▼                                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    QEMU LINUX VM                            │  │
│  │                                                             │  │
│  │   psDoom-ng ──▶ Process Respawner ──▶ File Spawner         │  │
│  │                       │                                     │  │
│  │                 ┌─────┴─────┐                               │  │
│  │                 ▼           ▼                               │  │
│  │              cat vim     python top                         │  │
│  │            (zombie)      (imp)                              │  │
│  │                                                             │  │
│  │   Kill monster ──▶ Process dies ──▶ Respawns after delay   │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  Your Windows processes are completely safe!                     │
└──────────────────────────────────────────────────────────────────┘
```

**Safe mode** - processes only die inside the QEMU virtual machine.

---

## Features

- **Process Respawner** - killed processes respawn based on enemy tier
- **File Spawner** - dynamically creates processes for the game
- Native Windows GUI wrapper
- Embedded QEMU virtual machine

---

## Requirements

- Windows 10 version 1809+
- QEMU for Windows (bundled or installed separately)
- [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) (usually pre-installed)

---

## Building

```batch
cd win32
build.bat release
```

Or with CMake:

```powershell
mkdir build && cd build
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
```

---

## Usage

1. Run `fightthemachine.exe`
2. Wait for VM to boot
3. Play DOOM - kill monsters, kill VM processes
4. Processes respawn after delay

---

## Controls

| Key | Action |
|-----|--------|
| Arrow Keys | Move |
| Ctrl | Fire |
| Space | Open doors |
| F11 | Toggle fullscreen |
| ESC | Exit fullscreen |

---

## Credits

Built on open source foundations:

- **[DOOM](https://github.com/id-Software/DOOM)** - id Software (1993)
- **[Chocolate Doom](https://www.chocolate-doom.org/)** - Simon Howard
- **[psDoom](http://psdoom.sourceforge.net/)** - Dennis Chao (1999)
- **[psDoom-ng](https://github.com/orsonteodoro/psdoom-ng)** - Orson Teodoro
- **[QEMU](https://www.qemu.org/)** - Fabrice Bellard

**GPL v2 License** - Free and open source software.
