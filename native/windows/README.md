# Fight the Machine - Native Windows Port

**Kill real Windows processes by killing DOOM monsters.**

```
┌──────────────────────────────────────────────────────────────────┐
│                      WINDOWS DESKTOP                              │
│                                                                   │
│  fightthemachine.exe ──┬── Toolhelp32 ──▶ Enumerate processes    │
│                        ├── TerminateProcess ──▶ Kill processes   │
│                        └── Blacklist ──▶ Protect system procs    │
│                                                                   │
│  notepad.exe   chrome.exe   discord.exe   explorer.exe           │
│   (zombie)      (demon)      (demon)      (PROTECTED)            │
│                                                                   │
│  NO RESPAWNER - killed processes stay dead!                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

1. Extract the ZIP file
2. Run `run.bat`
3. Kill monsters = Kill processes

---

## Configuration

Edit `fightthemachine.cfg`:

```ini
# Window scale (2-6): 2=640x400, 3=960x600, 4=1280x800
SCALE=2

# Windowed mode (1=yes, 0=fullscreen)
WINDOWED=1

# Safe mode (1=only safe processes, 0=all processes)
SAFE_MODE=1
```

---

## Safe Mode

**Enabled by default.** Only these processes can be killed:
- `notepad.exe`
- `calc.exe`
- `mspaint.exe`

Disable at your own risk.

---

## Protected Processes

These system processes are **always protected**:

| Category | Processes |
|----------|-----------|
| Windows Core | `system`, `smss.exe`, `csrss.exe`, `wininit.exe`, `services.exe`, `lsass.exe`, `svchost.exe` |
| Windows Shell | `explorer.exe`, `dwm.exe` |
| Security | `msmpeng.exe`, `securityhealthservice.exe` |

---

## Building from Source

### Prerequisites

1. Install [MSYS2](https://www.msys2.org/)
2. Open **MSYS2 MINGW64** terminal
3. Install dependencies:

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
          mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \
          mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng \
          git make
```

### Build

```bash
cd native/windows
./build-windows.sh
```

Output: `build/fightthemachine.exe`

---

## Cheat Codes

| Cheat | Effect |
|-------|--------|
| `sudo` | God mode + all weapons |
| `iddqd` | God mode |
| `idkfa` | All weapons and ammo |
| `idclip` | Walk through walls |

---

## Credits

Built on open source foundations:

- **[DOOM](https://github.com/id-Software/DOOM)** - id Software (1993)
- **[Chocolate Doom](https://www.chocolate-doom.org/)** - Simon Howard
- **[psDoom](http://psdoom.sourceforge.net/)** - Dennis Chao (1999)
- **[psDoom-ng](https://github.com/orsonteodoro/psdoom-ng)** - Orson Teodoro
- **[psDoom-ng fork](https://github.com/keymon/psdoom-ng)** - keymon

**GPL v2 License** - Free and open source software.

---

## Disclaimer

**USE AT YOUR OWN RISK.** This software terminates real Windows processes. While safety measures are in place, the authors are not responsible for any damage caused.
